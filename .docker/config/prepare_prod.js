use  DB_NAME;
db.dropDatabase();
sleep(10);
use  DB_NAME;
db.dropDatabase();
sleep(20);
use  DB_NAME;
db.dropDatabase();
sleep(20);
use  DB_NAME_dev;
sleep(10);
db.copyDatabase('DB_NAME_dev', 'DB_NAME');
