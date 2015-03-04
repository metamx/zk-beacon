{expect} = require("chai")

exec = require('child_process').exec
async = require('async')
zookeeper = require('node-zookeeper-client')

beacon = require '../src/beacon'

zkClient = null

rmStar = (path, callback) ->
  zkClient.getChildren(path, (err, children) ->
    if err
      if err.getCode() is zookeeper.Exception.NO_NODE
        callback(null)
      else
        callback(err)
      return

    async.map(
      children
      (child, callback) -> zkClient.remove(path + '/' + child, callback)
      (err) -> callback(err)
    )
    return
  )


simpleExec = (cmd, done) ->
  exec(cmd, (err, stdout, stderr) ->
    if err
      console.log('  stdout: ' + stdout)
      console.log('  stderr: ' + stderr)
      console.log('  exec err: ' + err)
    done(err)
  )

describe 'Beacon', ->
  @timeout 5000
  myBeacon = null

  payload = {
    address: '10.20.30.40'
    port: 8080
  }

  beforeEach (done) ->
    zkClient = zookeeper.createClient(
      'localhost:2181',
      {
        sessionTimeout: 1000
        spinDelay: 100
        retries: 3
      }
    )
    zkClient.connect()

    async.series([
      (callback) -> simpleExec('zkServer.sh start', callback)
      (callback) -> rmStar('/beacon/discovery/my:service', callback)
      (callback) -> zkClient.mkdirp('/beacon', callback)
    ], (err) ->
      return done(err) if err
      myBeacon = beacon {
        servers: 'localhost:2181/beacon'
        path: '/discovery/my:service'
        payload
      }
      done()
    )

  afterEach (done) ->
    setTimeout(done, 1000) # add buffer for zkServer teardown time

  it "connects initially", (done) ->
    setTimeout((->
      expect(myBeacon.connected).to.be.true
      zkClient.getData(
        "/beacon/discovery/my:service/#{myBeacon.id}"
        (error, data, stat) ->
          expect(error).to.not.exist
          expect(JSON.parse(data.toString())).to.deep.equal(payload)

          async.series([
            (callback) -> rmStar('/beacon/discovery/my:service', callback)
            (callback) -> simpleExec('zkServer.sh stop', callback)
          ], done)
      )
    ), 50)

  it "reconnect when server comes back", (done) ->
    checked = false
    myBeacon.on('disconnected', ->
      return if checked
      checked = true
      expect(myBeacon.connected).to.be.false

      checked = false
      myBeacon.on('connected', ->
        return if checked
        checked = true
        expect(myBeacon.connected).to.be.true

        async.series([
          (callback) -> rmStar('/beacon/discovery/my:service', callback)
          (callback) -> simpleExec('zkServer.sh stop', callback)
        ], done)
      )
      setTimeout(
        -> simpleExec('zkServer.sh start', ->)
      , 1000)

    )
    simpleExec('zkServer.sh stop', ->)

  it "emits expired event and replaces the expired client", (done) ->
    firstClient = myBeacon.__client

    setTimeout( ->
      checked = false
      myBeacon.on('expired', ->
        return if checked
        checked = true
        expect(myBeacon.connected).to.be.false

        checked = false
        myBeacon.on('connected', ->
          return if checked
          checked = true
          expect(myBeacon.connected).to.be.true
          expect(myBeacon.__client).not.to.equal(firstClient)

          async.series([
            (callback) -> rmStar('/beacon/discovery/my:service', callback)
            (callback) -> simpleExec('zkServer.sh stop', callback)
          ], done)
        )
      )
      myBeacon.__client.onConnectionManagerState(-3) # SESSION_EXPIRED EVENT CODE
    , 1000)
