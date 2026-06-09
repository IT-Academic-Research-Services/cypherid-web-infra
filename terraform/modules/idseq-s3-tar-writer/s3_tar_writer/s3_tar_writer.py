import io, os, sys, boto3, urllib3, tarfile, subprocess, time, argparse, json, botocore, tempfile
from stream_unzip import stream_unzip
from typing import List, Any, Dict, Generator, Optional
from urllib.parse import urlparse
from contextlib import closing
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("s3_tar_writer")

# Authorized via instance metadata in production.
# Should work with your AWS credentials locally.
s3 = boto3.resource('s3')


def parse_s3_url(s3_url):
    result = urlparse(s3_url, allow_fragments=False)
    if result.scheme != "s3" or result.netloc == "" or result.path == "":
        logger.error(f"s3_url is malformed: {s3_url}")
        return None
    return {
        "bucket_name": result.netloc,
        "key": result.path.lstrip('/')
    }


def get_s3_object_from_s3_url(s3_url):
    parsed_s3_url = parse_s3_url(s3_url)
    if parsed_s3_url is None:
        return None
    return s3.Object(parsed_s3_url["bucket_name"], parsed_s3_url["key"])


def human_readable_file_size(size, decimal_places=1):
    for unit in ["B", "KiB", "MiB", "GiB", "TiB"]:
        if size < 1024.0:
            break
        size /= 1024.0
    return f"{size:.{decimal_places}f}{unit}"


class ZipFileStream(io.FileIO):
    def __init__(self, unzipped_chunks: Generator[bytes, None, None]):
        self._unzipped_chunks = unzipped_chunks
        self._current_chunk = b''

    def read(self, size=-1) -> Optional[bytes]:
        result = b''
        try:
            while size < 0 or len(result) < size:
                if not self._current_chunk:
                    self._current_chunk = next(self._unzipped_chunks)
                n = min(size - len(result), len(self._current_chunk))
                result += self._current_chunk[:n]
                self._current_chunk = self._current_chunk[n:]
            return result
        except StopIteration:
            return result or None


class TarWriterTask:
    ERROR_SRC_URLS_REQUIRED = "at least one --src-urls is required"
    ERROR_TAR_NAMES_AND_SRC_URLS_EQUAL = "number of arguments should be equal for --src-urls and --tar-names"
    ERROR_DEST_URL_REQUIRED = "--dest-url is required"
    ERROR_DEST_URL_MALFORMED = "dest-url is malformed"

    def __init__(self):
        self.http = urllib3.PoolManager()

        # Maintain a list of src urls that failed to process.
        self.failed_src_urls = []

        # Stores the last time we sent a progress ping.
        self.last_progress_time = time.time()

    def execute(self, args_arr):
        try:
            # First, parse the error_url.
            # This allows us to ping the error_url if there is an error parsing the full set of arguments.
            self.parse_error_url(args_arr)

            # Parse all the other command line arguments.
            self.parse_args(args_arr)

            # Validate arguments
            self.validate_args()

            # Parse src urls and create s3 objects
            self.create_s3_objects_from_src_urls()

            # Stream the file with TarWriter.
            self.stream_tar_file()

            # Send success ping.
            self.send_success_ping()
        except (Exception, SystemExit) as e:
            if self.error_url is not None:
                try:
                    r = self.http.request('POST', self.error_url)
                    if r.status != 200:
                        logger.error(f"Failed to ping error url. Status: {r.status}")
                    else:
                        logger.info("Error ping sent.")
                except Exception as ping_error:
                    logger.error(f"Failed to ping error url. Error: {ping_error}")
            raise e

    def parse_error_url(self, args_arr):
        self.error_url_parser = argparse.ArgumentParser(add_help=False)
        self.error_url_parser.add_argument(
            '--error-url', help='''
                The url to POST to when the process has failed.
                Any errors will be included in 'error_message' field.
            '''
        )
        args, _unknown_args = self.error_url_parser.parse_known_args(args_arr)
        self.error_url = args.error_url

    def parse_args(self, args_arr):
        parser = argparse.ArgumentParser(parents=[self.error_url_parser])
        parser.add_argument(
            '--src-urls', nargs='*', default=[], help="The s3 source urls to be combined into the tarfile."
        )
        parser.add_argument(
            '--tar-names', nargs='*', default=[], help='''
                The destination name or path for each source file in the tarfile.
            '''
        )
        parser.add_argument(
            '--dest-url', help="The url that the tarfile will be streamed to."
        )
        parser.add_argument(
            '--success-url', help='''
                The url to POST to when the process has succeeded.
                Any warnings will be included in 'error_message' field.
            '''
        )
        parser.add_argument(
            '--progress-url', help='''
                The url to POST to for progress updates.
                The progress will be included as a float between 0 and 1 in the 'progress' field.
            '''
        )
        parser.add_argument(
            '--progress-delay', type=int, default=300, help="The minimum time, in seconds, between status updates"
        )

        self.args = parser.parse_args(args_arr)

    def validate_args(self):
        if len(self.args.src_urls) == 0:
            raise ValueError(TarWriterTask.ERROR_SRC_URLS_REQUIRED)

        if len(self.args.tar_names) != len(self.args.src_urls):
            raise ValueError(TarWriterTask.ERROR_TAR_NAMES_AND_SRC_URLS_EQUAL)

        if self.args.dest_url is None:
            raise ValueError(TarWriterTask.ERROR_DEST_URL_REQUIRED)

        # Parse the dest url to validate it.
        parsed_dest_url = parse_s3_url(self.args.dest_url)

        if parsed_dest_url is None:
            raise ValueError(f"{TarWriterTask.ERROR_DEST_URL_MALFORMED}: {self.args.dest_url}")

    def create_s3_objects_from_src_urls(self):
        self.src_objects = []
        self.s3_key_to_tar_name = {}

        for src_url, tar_name in zip(self.args.src_urls, self.args.tar_names):
            s3_object = get_s3_object_from_s3_url(src_url)
            if s3_object is not None:
                self.src_objects.append(s3_object)
                self.s3_key_to_tar_name[s3_object.key] = tar_name
            else:
                self.failed_src_urls.append(src_url)

    def send_progress_ping(self, progress):
        cur_time = time.time()
        if self.args.progress_url is not None and cur_time - self.last_progress_time > self.args.progress_delay:
            r = self.http.request('POST', self.args.progress_url, fields={'progress': str(progress)})
            if r.status != 200:
                logger.error(f"Failed to ping progress url. Status: {r.status}")
            else:
                logger.info("Progress ping sent. %3.1f complete." % (progress * 100))
            self.last_progress_time = cur_time

    def stream_tar_file(self):
        start_time = time.time()
        logger.info(f"Starting tarfile streaming to {self.args.dest_url}...")
        s3_writer = subprocess.Popen(["aws", "s3", "cp", "-", self.args.dest_url], stdin=subprocess.PIPE)
        self.tar_writer = TarWriter(
            self.src_objects,
            self.s3_key_to_tar_name,
            lambda progress: self.send_progress_ping(progress)
        )
        self.tar_writer.stream(s3_writer.stdin)
        s3_writer.stdin.close()
        s3_writer.wait()
        assert s3_writer.returncode == os.EX_OK
        self.failed_src_urls += self.tar_writer.failed_src_urls
        logger.info("Tarfile of size %s written successfully in %3.1f seconds" % (
            human_readable_file_size(self.tar_writer.total_size_processed), time.time() - start_time
        ))

    def send_success_ping(self):
        if self.args.success_url is not None:
            success_fields: Dict[str, Any] = {}

            # If there are any failed src urls, send them with the success ping.
            if len(self.failed_src_urls) > 0:
                success_fields["error_type"] = "FailedSrcUrlError"
                success_fields["error_data"] = self.failed_src_urls

            r = self.http.request(
                'POST',
                self.args.success_url,
                headers={'Content-Type': 'application/json'},
                body=json.dumps(success_fields).encode("utf-8")
            )
            if r.status != 200:
                logger.error(f"Failed to ping success url. Status: {r.status}")
            else:
                logger.info("Success ping sent.")


class TarWriter:
    def __init__(self, src_objects, s3_key_to_tar_name, on_progress):
        self.http = urllib3.PoolManager()
        # src objects can be s3.Object or s3.ObjectSummary
        self.src_objects = src_objects
        # A map from the key of the src s3 object to the intended tar name (or path) in the tarfile.
        self.s3_key_to_tar_name = s3_key_to_tar_name
        # The function to call with the current progress whenever an additional file is streamed.
        self.on_progress = on_progress
        # A list of src urls that we failed to fetch or stream
        self.failed_src_urls = []
        # The total file size that we've processed.
        self.total_size_processed = 0

    def get_presigned_url(self, s3_object):
        return s3_object.meta.client.generate_presigned_url(
            ClientMethod='get_object',
            Params=dict(Bucket=s3_object.bucket_name, Key=s3_object.key)
        )

    def get_tarinfo(self, name, size):
        tarinfo = tarfile.TarInfo(name)
        tarinfo.mtime = time.time()
        tarinfo.size = size
        self.total_size_processed += size

        return tarinfo

    def stream_zip_files_to_tar(self, src_zip_s3_object, zip_stream, tar):
        dir_path = self.s3_key_to_tar_name[src_zip_s3_object.key]
        for file_name, file_size, unzipped_chunks in stream_unzip(zip_stream):
            decoded_file_name = file_name.decode("utf-8")
            if decoded_file_name[-1] != '/':
                tar_info = self.get_tarinfo(os.path.join(dir_path, decoded_file_name), file_size)
                tar.addfile(tar_info, ZipFileStream(unzipped_chunks))

    def stream(self, dest_fh):
        with tarfile.open(fileobj=dest_fh, mode='w|gz') as tar:
            for index, src_object in enumerate(self.src_objects):
                original_s3_path = f"s3://{src_object.bucket_name}/{src_object.key}"
                s3_object_file_extension = os.path.splitext(src_object.key)[1]
                logger.info(f"Opening file #{original_s3_path}...")
                src_url = self.get_presigned_url(src_object)
                try:
                    with closing(self.http.request("GET", src_url, preload_content=False)) as fh:
                        if s3_object_file_extension == ".zip":
                            self.stream_zip_files_to_tar(src_object, fh, tar)
                        else:
                            size = src_object.size if hasattr(src_object, "size") else src_object.content_length
                            tar.addfile(self.get_tarinfo(self.s3_key_to_tar_name[src_object.key], size), fh)
                except botocore.exceptions.ClientError:
                    logger.error(f"Could not fetch s3_url: {original_s3_path}")
                    # If there is a failure (e.g. the file doesn't exist), add the url to failed_src_urls and continue.
                    self.failed_src_urls.append(original_s3_path)
                self.on_progress((index + 1) / len(self.src_objects))


if __name__ == '__main__':
    task = TarWriterTask()
    task.execute(sys.argv[1:])
