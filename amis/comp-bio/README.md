# comp bio instance

## jupyter notebook

To connect to a jupyter notebook you must use an ssh tunnel. To open this tunnel run this on your **local** instance:

```bash
aegea ssh -NL 8888:localhost:8888 ubuntu@your-instance-name
```

## IGV

IGV has a graphical user interface. It is a little strange to run an application with a graphical user interface remotely. You may see some errors and need to re-start. To run the app you must connect you your instance with the `-X` option in `aegea ssh`:

```bash
aegea ssh -XC4 ubuntu@your-instance-name
```

To start IGV run:

```bash
~/igv.sh
```

## IGV Command Line Tools

To use IGV tools  run:

```bash
igvtoos
```

## Remote Browser

It is possible to use a web browser on this instance. Unfortunately with such applications input lag is inevitable; the experience will be very slow. For the best experience it is recommended you launch the instance in the AWS region physically closest to you and use an instance with high bandwidth (instances ending in `n` are ideal, like an `m5n.12xlarge`). To use the browser you must connect via ssh with the following options:

```bash
ssh -XC4 ubuntu@your-instance-name
```

Once connected open the browser by running `firefox`. You will see some errors in the console, disregard these.
