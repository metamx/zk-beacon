{expect} = require("chai")

exec = require('child_process').exec
async = require('async')
zookeeper = require('node-zookeeper-client')

beacon = require '../src/beacon'

zkClient = zookeeper.createClient(
  'localhost:2181',
  {
    sessionTimeout: 10000
    spinDelay: 1000
    retries: 0
  }
)

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

zkClient.connect()

simpleExec = (cmd, done) ->
  exec(cmd, (err, stdout, stderr) ->
    if err
      console.log(cmd)
      console.log('  stdout: ' + stdout)
      console.log('  stderr: ' + stderr)
      console.log('  exec err: ' + err)
    done(err)
  )

describe 'Beacon', ->
  describe 'normal function', ->
    @timeout 5000
    myBeacon = null

    payload = {
      address: '10.20.30.40'
      port: 8080
    }

    before (done) ->
      async.series([
        (callback) -> simpleExec('zkServer start', callback)
        (callback) -> rmStar('/beacon/discovery/my:service', callback)
        (callback) -> zkClient.mkdirp('/beacon', callback)
      ], done)

    after (done) ->
      async.series([
        (callback) -> rmStar('/beacon/discovery/my:service', callback)
        (callback) -> simpleExec('zkServer stop', callback)
      ], done)

    it "works initially", (done) ->
      myBeacon = beacon {
        servers: 'localhost:2181/beacon'
        path: '/discovery/my:service'
        payload
      }

      setTimeout((->
        expect(myBeacon.connected).to.be.true
        zkClient.getData(
          "/beacon/discovery/my:service/#{myBeacon.id}"
          (error, data, stat) ->
            expect(error).to.not.exist
            expect(JSON.parse(data.toString())).to.deep.equal(payload)
            done()
        )
      ), 50)

    it "works on disconnect", (done) ->
      async.series([
        (callback) -> simpleExec('zkServer stop', callback)
        (callback) -> setTimeout(callback, 50)
        (callback) ->
          expect(myBeacon.connected).to.be.false
          callback()
      ], done)

    it "works on reconnect", (done) ->
      async.series([
        (callback) -> setTimeout(callback, 1000)
        (callback) -> simpleExec('zkServer start', callback)
        (callback) -> setTimeout(callback, 1000)
        (callback) ->
          expect(myBeacon.connected).to.be.true
          callback()
      ], done)

