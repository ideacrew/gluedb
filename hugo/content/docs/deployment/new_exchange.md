---
title: Standing Up a New Exchange
date: 2021-03-14T12:12:25-05:00
draft: false
---

This page will tell you how to stand up a new 'empty' exchange.  It also functions as a checklist for tasks that need to be performed while doing so.

## GlueDB Setup

In order to have a functioning GlueDB environment, you will need to perform the following:
1. Restore ONLY the users collection from DC
2. Configure `exchange.yml` with exchange-specific parameters
3. Run index creation tasks:
   1. `rake db:mongoid:remove_indexes`
   2. `rake db:mongoid:create_indexes`
4. Create carrier profiles, including one for the exchange
6. Run trading partner creation task (`lib/tasks/create_trading_partners.rake`)
7. Load plans from enroll export

## B2B Setup

1. Load B2B Image
2. Populate B2B Settings and Data
   1. Load Document Definitions
   2. Create listening channels
   3. Create Trading Partners and Channels
   4. Create and Deploy Trading Partner Agreements
3. Load Composites into SOA