# Library deprecated
As of 2020-01-22, the service that had been provided at earningscalendar.net is no longer free. Please see [zacks-estimates-financial-statements](https://github.com/evdubs/zacks-estimates-financial-statements) for another earnings calendar ETL program.

# ecnet-earnings-calendar
These Racket programs will download earnings calendar JSON documents from https://earningscalendar.net and insert the
data into a PostgreSQL database. The intended usage is:

```
$ racket extract.rkt
$ racket transform-load.rkt
```

The provided schema.sql file shows the expected schema within the target PostgreSQL instance. This process assumes you 
can write to a /var/tmp/ecnet/earnings-calendar folder. This process also assumes you have loaded your database with the NASDAQ 
symbol file information. This data is provided by the [nasdaq-symbols](https://github.com/evdubs/nasdaq-symbols) project.

### Dependencies

It is recommended that you start with the standard Racket distribution. With that, you will need to install the following packages:

```bash
$ raco pkg install --skip-installed gregor tasks threading
```
