rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongo-0.mongo.default.svc.cluster.local:27017" },
    { _id: 1, host: "mongo-1.mongo.default.svc.cluster.local:27017" },
    { _id: 2, host: "mongo-2.mongo.default.svc.cluster.local:27017" },
  ],
});

rs.status();

rs.slaveOk();

```
use pole;

db.users.insert({name: "Canh", "age": 26})

db.users.find().pretty();

k exec -it mongo-1 mongo

```;
