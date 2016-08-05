![light the beacon](https://i2.wp.com/content9.flixster.com/question/66/59/71/6659719_std.jpg?zoom=2)
# zk-beacon
zk-beacon is a zookeeper announcement library designed to be used for service discovery. At it's 
core it uses ephemeral connections to zookeeper to insert a payload under the `path` defined in the 
configuration, and then just maintains this connection indefinitely, recovering from disconnections 
and session expiration as necessary to... keep the beacon lit. It is built on top of 
[node-zookeeper-client](https://github.com/alexguan/node-zookeeper-client). 

This enables operation as a service discovery beacon by using an address and a port as the payload,
and registering the path as the service identifier. It exports 2 main types, `ZookeeperBeacon` 
a class describing the beacon itself, and `ZookeeperBeaconOptions`, an interface
which describes the configuration to pass to the `ZookeeperBeacon` constructor.

`ZookeeperBeaconOptions` has 3 required properties, `servers` which takes a string or list of strings 
that can resolve to a zookeeper server as described in the connection string documentation of 
[node-zookeeper-client](https://github.com/alexguan/node-zookeeper-client#client-createclientconnectionstring-options), 
`path` which describes the parent path which the announcement will be created under, and `payload` 
which describes the contents that will be added to the node under the path. A fourth, optional parameter, 
`spinDelay`, is used to determine the rate at which the beacon will try to reconnect to zookeeper.

`ZookeeperBeacon` is also an `EventEmitter` and will emit a handful of events described by `BeaconEvents`
which is also exported by this library.

```
CONNECTED: "connected",
DISCONNECTED: "disconnected",
EXPIRED: "expired",
CREATED: "created",
ERROR: "error"
```

#### example
```typescript
import beacon = require('zk-beacon');

const serviceBeacon = beacon({
    servers: 'localhost:2181/discovery',
    path: `/myserviceidentifier`,
    payload: {
        address: 'localhost',
        port: 8080
    }
});

serviceBeacon.on('connected', () => {
    console.log('beacon connected');
});
```

## Development
`npm run build` to compile.

The `ZookeeperBeacon` test currently require a local installation of zookeeper to run successfully, specified
by the `zkServerCommandPath` variable which is defined near the beginning of the tests.