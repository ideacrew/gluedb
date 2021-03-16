---
title: Standing Up a New Exchange
date: 2021-03-14T12:12:25-05:00
draft: false
---

{{< table_of_contents >}}

This page will tell you how to stand up a new 'empty' exchange.  It also functions as a checklist for tasks that need to be performed while doing so.

## GlueDB Setup

In order to have a functioning GlueDB environment, you will need to perform the following:
1. Restore ONLY the users collection from DC MongoDB
2. Configure `exchange.yml` with exchange-specific parameters
3. Run index creation tasks:
   1. `rake db:mongoid:remove_indexes`
   2. `rake db:mongoid:create_indexes`
4. Create carrier profiles, including one for the exchange
6. Run trading partner creation task (`lib/tasks/create_trading_partners.rake`)
7. Load plans from enroll export
8. Add carriers and carrier classes to edi_codec

### Configure `exchange.yml` with exchange-specific parameters

**Performed By: Devops**

The `exchange.yml` file has the following template:

```
receiver_id: '<exchange fein>'
hbx_id: '<exchange abbreviation>'
environment: '<environment name>'
invalid_argument_queue: '<exchange abbreviation>.errors.invalid_arguements'
processing_failure_queue: '<exchange abbreviation>.errors.processing_failures'
request_exchange: '<exchange abbreviation>.<environment name>.e.direct.requests'
event_exchange: '<exchange abbreviation>.<environment name>.e.topic.events'
event_publish_exchange: '<exchange abbreviation>.<environment name>.e.fanout.events'
amqp_uri: 'amqp://<amqp user name>:<amqp user password>@<amqp server ip>:<amqp server port>'
file_storage_uri: 'http://'
```

Where each item enclosed in `<>` is a value which must be substituted.

The tokens are:
* `amqp server ip` - the IP of the server on which RabbitMQ is running
* `amqp server port` - the port of the server on which RabbitMQ is running
* `amqp user name` - the name of the user account with which to connect to RabbitMQ
* `amqp user password` - the password of the user with which to connect to RabbitMQ
* `environment name` - the name of the environment, such as prod, qa, etc.
* `exchange abbreviation` - the short abbreviation of the exchange, lower case.  An example is `dc0`.
* `exchange fein` - the FEIN used by the exchange to transmit EDI.

## B2B Setup

1. Load B2B Image
2. Populate B2B Settings and Data
   1. Load Document Definitions
   2. Create listening channels
   3. Create Trading Partners and Channels
   4. Create and Deploy Trading Partner Agreements
3. Load Composites into SOA
   1. Configure Composites
   2. Compile Composites
   3. Deploy Composites