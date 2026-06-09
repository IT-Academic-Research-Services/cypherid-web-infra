import unittest, subprocess, sys, os, uuid, json
from unittest.mock import MagicMock, call

from s3_tar_writer.s3_tar_writer import TarWriterTask

TEST_INPUT_PATH = "s3://idseq-services/s3-tar-writer/test-input"
TEST_OUTPUT_PATH = "s3://idseq-services/s3-tar-writer/test-output"


class TestS3TarWriter(unittest.TestCase):
    # When this is called, the TarWriterTask will no longer execute the s3 calls.
    # Useful when the test is mainly testing parameter handler rather than the s3 call itself.
    @staticmethod
    def mock_out_s3_calls(task):
        task.stream_tar_file = MagicMock()

    # When this is called, the TarWriterTask will no longer make http requests,
    # EXCEPT s3 calls (which are handled with an http object in the TarWriter class)
    # This is useful for testing pings to success-url, error-url.
    @staticmethod
    def mock_out_http_request(task):
        task.http.request = MagicMock()
        task.http.request.return_value.status = 200

    # Download a tar file from s3 and inspect the contents.
    # Return the lines from tar -tvf tarfile
    @staticmethod
    def inspect_s3_tar_file(tar_file_path):
        local_tmp_path = f"/tmp/{str(uuid.uuid4())}"

        try:
            subprocess.call([
                "aws",
                "s3",
                "cp",
                tar_file_path,
                f"{local_tmp_path}/"
            ])

            # Inspect the contents of the tar file.
            output = subprocess.check_output([
                "tar",
                "-tvf",
                f"{local_tmp_path}/{os.path.basename(tar_file_path)}"
            ]).decode('utf-8')

            return output.split("\n")
        finally:
            # Clean up the downloaded tar.
            subprocess.call([
                "rm",
                "-rf",
                f"{local_tmp_path}/{os.path.basename(tar_file_path)}"
            ])

    def test_basic_usage(self):
        output_tar_path = f"{TEST_OUTPUT_PATH}/{str(uuid.uuid4())}.tar.gz"

        task = TarWriterTask()
        TestS3TarWriter.mock_out_http_request(task)
        task.execute([
            "--src-urls",
            f"{TEST_INPUT_PATH}/water_R1.fastq",
            f"{TEST_INPUT_PATH}/water_R2.fastq",
            f"{TEST_INPUT_PATH}/outputs.zip",
            "--tar-names",
            "water_R1_tar.fastq",
            "water_R2_tar.fastq",
            "project_name/sample_name_sample_id_accession_id/",
            "--dest-url",
            output_tar_path,
            "--success-url",
            "https://fake-success-url"
        ])

        task.http.request.assert_has_calls([
            call(
                'POST',
                'https://fake-success-url',
                headers={'Content-Type': 'application/json'},
                body=json.dumps({}).encode("utf-8")
            )
        ])

        # Download the resulting tar and inspect it.
        lines = TestS3TarWriter.inspect_s3_tar_file(output_tar_path)

        # Verify the file names and sizes inside the tar file.
        assert lines[0].find("207681") != -1
        assert lines[0].find("water_R1_tar.fastq") != -1
        assert lines[1].find("207681") != -1
        assert lines[1].find("water_R2_tar.fastq") != -1

        # Verify that the output.zip contents are inside the tar file.
        # Note: There's 14 items in the outputs.zip, but I am only checking for the first two.
        assert lines[2].find("project_name/sample_name_sample_id_accession_id/") != -1
        assert lines[2].find("no_host_1.fq.gz") != -1
        assert lines[3].find("project_name/sample_name_sample_id_accession_id/") != -1
        assert lines[3].find("no_host_2.fq.gz") != -1

    # If some of the src urls were malformed or not found,
    # verify that the tar writer still writes all the valid src urls.
    def test_malformed_or_missing_s3_urls(self):
        output_tar_path = f"{TEST_OUTPUT_PATH}/{str(uuid.uuid4())}.tar.gz"

        task = TarWriterTask()
        TestS3TarWriter.mock_out_http_request(task)

        task.execute([
            "--src-urls",
            "MALFORMED_SRC_URL",
            "s3://FAKE/NONEXISTENT_URL",
            f"{TEST_INPUT_PATH}/water_R1.fastq",
            f"{TEST_INPUT_PATH}/water_R2.fastq",
            "--tar-names",
            "MALFORMED_SRC_URL",
            "NONEXISTENT_URL",
            "water_R1_tar.fastq",
            "water_R2_tar.fastq",
            "--dest-url",
            output_tar_path,
            "--success-url",
            "https://fake-success-url"
        ])

        # Failed src urls should be sent in success ping.
        task.http.request.assert_has_calls([
            call(
                'POST',
                'https://fake-success-url',
                headers={'Content-Type': 'application/json'},
                body=json.dumps({
                    "error_type": "FailedSrcUrlError",
                    "error_data": ["MALFORMED_SRC_URL", "s3://FAKE/NONEXISTENT_URL"]
                }).encode("utf-8")
            )
        ])

        # Download the resulting tar and inspect it.
        lines = TestS3TarWriter.inspect_s3_tar_file(output_tar_path)

        # Verify the file names and sizes inside the tar file.
        assert lines[0].find("207681") != -1
        assert lines[0].find("water_R1_tar.fastq") != -1
        assert lines[1].find("207681") != -1
        assert lines[1].find("water_R2_tar.fastq") != -1

    def test_missing_src_url(self):
        output_tar_path = f"{TEST_OUTPUT_PATH}/{str(uuid.uuid4())}.tar.gz"

        task = TarWriterTask()
        TestS3TarWriter.mock_out_http_request(task)
        TestS3TarWriter.mock_out_s3_calls(task)

        with self.assertRaises(ValueError) as context:
            task.execute([
                "--dest-url",
                output_tar_path,
                "--error-url",
                "https://fake-error-url"
            ])

        self.assertEqual(str(context.exception), TarWriterTask.ERROR_SRC_URLS_REQUIRED)
        task.http.request.assert_has_calls([
            call(
                'POST',
                'https://fake-error-url'
            )
        ])

    def test_tar_names_and_src_urls_unequal(self):
        output_tar_path = f"{TEST_OUTPUT_PATH}/{str(uuid.uuid4())}.tar.gz"

        task = TarWriterTask()
        TestS3TarWriter.mock_out_http_request(task)
        TestS3TarWriter.mock_out_s3_calls(task)

        with self.assertRaises(ValueError) as context:
            task.execute([
                "--src-urls",
                f"{TEST_INPUT_PATH}/water_R1.fastq",
                f"{TEST_INPUT_PATH}/water_R2.fastq",
                "--tar-names",
                "water_R1_tar.fastq",
                "--dest-url",
                output_tar_path,
                "--error-url",
                "https://fake-error-url"
            ])

        self.assertEqual(str(context.exception), TarWriterTask.ERROR_TAR_NAMES_AND_SRC_URLS_EQUAL)
        task.http.request.assert_has_calls([
            call(
                'POST',
                'https://fake-error-url'
            )
        ])

    def test_missing_dest_url(self):
        task = TarWriterTask()
        TestS3TarWriter.mock_out_http_request(task)
        TestS3TarWriter.mock_out_s3_calls(task)

        with self.assertRaises(ValueError) as context:
            task.execute([
                "--src-urls",
                f"{TEST_INPUT_PATH}/water_R1.fastq",
                f"{TEST_INPUT_PATH}/water_R2.fastq",
                "--tar-names",
                "water_R1_tar.fastq",
                "water_R2_tar.fastq",
                "--error-url",
                "https://fake-error-url"
            ])

        self.assertEqual(str(context.exception), TarWriterTask.ERROR_DEST_URL_REQUIRED)
        task.http.request.assert_has_calls([
            call(
                'POST',
                'https://fake-error-url'
            )
        ])

    def test_malformed_dest_url(self):
        task = TarWriterTask()
        TestS3TarWriter.mock_out_http_request(task)
        TestS3TarWriter.mock_out_s3_calls(task)

        with self.assertRaises(ValueError) as context:
            task.execute([
                "--src-urls",
                f"{TEST_INPUT_PATH}/water_R1.fastq",
                f"{TEST_INPUT_PATH}/water_R2.fastq",
                "--tar-names",
                "water_R1_tar.fastq",
                "water_R2_tar.fastq",
                "--dest-url",
                "MALFORMED_URL",
                "--error-url",
                "https://fake-error-url"
            ])

        self.assertEqual(str(context.exception), f"{TarWriterTask.ERROR_DEST_URL_MALFORMED}: MALFORMED_URL")
        task.http.request.assert_has_calls([
            call(
                'POST',
                'https://fake-error-url'
            )
        ])

    def test_progress_pings(self):
        output_tar_path = f"{TEST_OUTPUT_PATH}/{str(uuid.uuid4())}.tar.gz"

        task = TarWriterTask()
        TestS3TarWriter.mock_out_http_request(task)

        task.execute([
            "--src-urls",
            f"{TEST_INPUT_PATH}/water_R1.fastq",
            f"{TEST_INPUT_PATH}/water_R2.fastq",
            "--tar-names",
            "water_R1_tar.fastq",
            "water_R2_tar.fastq",
            "--dest-url",
            output_tar_path,
            "--success-url",
            "https://fake-success-url",
            "--error-url",
            "https://fake-error-url",
            "--progress-url",
            "https://fake-progress-url",
            "--progress-delay",
            "0"
        ])

        task.http.request.assert_has_calls([
            call(
                'POST',
                'https://fake-progress-url',
                fields={'progress': str(0.5)}
            ),
            call(
                'POST',
                'https://fake-progress-url',
                fields={'progress': str(1.0)}
            ),
            call(
                'POST',
                'https://fake-success-url',
                headers={'Content-Type': 'application/json'},
                body=json.dumps({}).encode("utf-8")
            )
        ])


if __name__ == '__main__':
    unittest.main()
