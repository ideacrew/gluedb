use admin

db.createUser({
  user: "edidb_dev_user",
  pwd: "edidb_dev_pass",
  roles: ["userAdminAnyDatabase", "dbAdminAnyDatabase", "readWriteAnyDatabase"]
}, {w: 1, j: true})

use edidb_dev

db.createUser({
  user: "edidb_dev_user",
  pwd: "edidb_dev_pass",
  roles: ["userAdmin", "dbAdmin", "dbOwner", "readWrite"]
}, {w: 1, j: true})

use edidb_test

db.createUser({
  user: "edidb_dev_user",
  pwd: "edidb_dev_pass",
  roles: ["userAdmin", "dbAdmin", "dbOwner", "readWrite"]
}, {w: 1, j: true})

sleep(1000)