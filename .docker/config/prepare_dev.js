use DB_NAME_dev;
db.dropDatabase();
sleep(10);
use DB_NAME_dev;
db.dropDatabase();
sleep(10);
use DB_NAME;
db.copyDatabase('DB_NAME', 'DB_NAME_dev');
