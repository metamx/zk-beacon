"use strict"

{EventEmitter} = require('events')
uuid = require('node-uuid')
zookeeper = require('node-zookeeper-client')
{CreateMode, Exception} = zookeeper

module.exports = ({servers, path, payload}) ->
  emitter = new EventEmitter()
  emitter.id = uuid.v1()
  emitter.connected = false

  connect = ->
    client = zookeeper.createClient(servers, {
      sessionTimeout: 1000
      spinDelay: 100
      retries: 3
    })

    client.on('connected', ->
      emitter.connected = true
      emitter.emit('connected')

      client.mkdirp(
        path
        (err) ->
          if err
            emitter.emit('error', new Error("Failed to create path: #{path} due to: #{err}."))
            return

          client.create(
            path + '/' + emitter.id
            new Buffer(JSON.stringify(payload))
            CreateMode.EPHEMERAL
            (err) ->
              if err and err.getCode() isnt Exception.NODE_EXISTS
                emitter.emit('error', new Error("Failed to create node: #{path}/#{emitter.id} due to: #{err}."))
                return

              emitter.emit('created', emitter.id)
              return
          )
          return
      )
    )

    client.on('disconnected', ->
      emitter.connected = false
      emitter.emit('disconnected')
    )

    client.on('expired', ->
      emitter.connected = false
      emitter.emit('expired')
    )

    emitter.__client = client
    client.connect()

  emitter.on('expired', ->
    connect()
  )
  connect()
  return emitter

