# nagios-container
Nagios container file, ideally for the use within Docker &amp; later podman

To use:

Clone repo and open your chosen shell inside folder (bash is the best)

`docker . build -t somename/nagios:latest-1`

After build has finished, enter the container:

`docker run -it --rm somename/nagios:latest-1`

Inside the container, start nagios:

```
service apache2 start
service nagios start
```
