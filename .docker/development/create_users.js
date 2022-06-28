use admin;
db.createRole({role: 'fullaccess', privileges: [{resource: {anyResource: true}, actions: ["anyAction"]}], roles: []});

db.createUser({
  user: "admin",
  pwd: "admin",
  roles: ["userAdminAnyDatabase", "dbAdminAnyDatabase", "readWriteAnyDatabase", "fullaccess"]
}, {w: 1, j: true});

db.system.version.update({"_id": "authSchema"}, {currentVersion: 3});

db.createUser({
  user: "edidb_dev_user",
  pwd: "edidb_dev_pass",
  roles: ["userAdmin", "dbAdmin", "dbOwner", "readWrite"]
}, {w: 1, j: true});

use edidb_dev;

db.createUser({
  user: "edidb_dev_user",
  pwd: "edidb_dev_pass",
  roles: ["userAdmin", "dbAdmin", "dbOwner", "readWrite"]
}, {w: 1, j: true});

use edidb_test

db.createUser({
  user: "edidb_test_user",
  pwd: "edidb_test_pass",
  roles: ["userAdmin", "dbAdmin", "dbOwner", "readWrite"]
}, {w: 1, j: true});

use admin;
db.system.version.update({"_id": "authSchema"}, {currentVersion: 5});

sleep(1000);
