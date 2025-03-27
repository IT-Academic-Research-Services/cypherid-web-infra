# on call instance

This instance has basic tools useful for performing on call tasks, like docker, nodejs, and ruby.

## Remote Browser

It is possible to use a web browser on this instance. Unfortunately with such applications input lag is inevitable; the experience will be very slow. For the best experience it is recommended you launch the instance in the AWS region physically closest to you and use an instance with high bandwidth (instances ending in `n` are ideal, like an `m5n.12xlarge`). To use the browser you must connect via ssh with the following options:

```bash
ssh -XC4 ubuntu@your-instance-name
```

Once connected open the browser by running `firefox`. You will see some errors in the console, disregard these.
