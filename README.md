# Docker-Nagios

Docker image for Nagios

Nagios Core 4.4.6 running on Ubuntu 18.04 LTS with NagiosGraph & NRPE & NRDP

## Quick & Easy

```bash
docker run --name nagios -p 8080:80 whumphrey/nagios
```

## Full TBD

```bash
docker run --name nagios  \
  -e MAIL_RELAY_HOST=[smtp.gmail.com]:587 \
  -e MAIL_INET_PROTOCOLS=ipv4 \
  -e NAGIOS_FQDN=monitoring.corp.local \
  -e NAGIOS_TIMEZONE=Europe/Zurich \
  -v /path/nagios/etc:/opt/nagios/etc \
  -v /path/nagios/var:/opt/nagios/var \
  -v /path/nagios/plugins:/opt/plugins \
  -v /path/nagios/scripts:/opt/scripts \
  -v /path/nagios/graph/var:/opt/nagiosgraph/var \
  -v /path/nagios/graph/etc:/opt/nagiosgraph/etc \
  -p 8080:80 whumphrey/nagios
```

## Configurations

Nagios Configuration lives in /opt/nagios/etc
NagiosGraph configuration lives in /opt/nagiosgraph/etc

There are a number of environment variables that you can use to adjust the behavior of the container:

| Environment Variable | Description |
|--------|--------|
| MAIL_RELAY_HOST | Set Postfix relay host |
| MAIL_INET_PROTOCOLS | set the IP version protocol in postfix |
| NAGIOS_FQDN | set the server Fully Qualified Domain Name in postfix |
| NAGIOS_TIMEZONE | set the timezone of the server |

### Credentials

The default credentials for the web interface is `nagiosadmin` / `nagios`

### Extra Plugins

* Nagios NRPE [<https://github.com/NagiosEnterprises/nrdp>]
* Nagios NRDP [<https://github.com/NagiosEnterprises/nrdp>]
* Nagiosgraph [<https://github.com/JasonRivers/nagiosgraph>]
* JR-Nagios-Plugins -  custom plugins from Jason Rivers [<https://github.com/JasonRivers/nagios-plugins>]
* WL-Nagios-Plugins -  custom plugins from William Leibzon [<https://github.com/willixix/WL-NagiosPlugins>]
* JE-Nagios-Plugins -  custom plugins from Justin Ellison [<https://github.com/justintime/nagios-plugins>]

Note: The path for the custom plugins will be /opt/scripts, you will need to reference this directory in your configuration scripts.

## Building

```bash
docker build -t nagios_x -f x_dev_dockerfile .
docker-compose -f x_dev_compose.yml up
docker run -v $PWD/x_dev_data/etc:/opt/nagios/etc -p 8086:80 nagios_x:latest

docker-compose -f x_dev_jr_compose.yml up

docker build -t nagios .
docker-compose up
docker run --name nagios -v $PWD/data/etc:/opt/nagios/etc -p 8080:80 nagios

docker build -t nagios:dev .
docker-compose -f dev_compose.yml up
docker run --name nagios -v $PWD/data/etc:/opt/nagios/etc -p 8080:80 nagios:dev
```

## Creds

* Jason Rivers [<https://github.com/JasonRivers/Docker-Nagios>]
