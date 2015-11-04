
"use strict";

import { EventEmitter } from 'events';
import uuid = require('node-uuid');
import zookeeper = require('node-zookeeper-client');

var beacon =  function (options) {

    var{ servers, path, payload } = options;

    var emitter : any = new EventEmitter();
    emitter.id = uuid.v1();
    emitter.connected = false;

    var connect = () => {
        var client = zookeeper.createClient(servers, {
            sessionTimeout: 1000,
            spinDelay: 100,
            retries: 3
        });

        client.on('connected', () => {
            emitter.connected = true;
            emitter.emit('connected');

            client.mkdirp(
                path,
                (err) => {
                    if (err) {
                        emitter.emit('error', new Error(`Failed to create path: ${path} due to: ${err}.`));
                        return;
                    }
                    client.create(
                        path + '/' + emitter.id,
                        new Buffer(JSON.stringify(payload)),
                        zookeeper.CreateMode.EPHEMERAL,
                        (createErr) => {
                            if (createErr && createErr.getCode() !== zookeeper.Exception.NODE_EXISTS) {
                                emitter.emit('error', new Error(`Failed to create node: ${path}/${emitter.id} due to: ${err}.`));
                                return;
                            }
                            emitter.emit('created', emitter.id);
                            return;
                        }
                    );
                    return;
                }
            );
        });

        client.on('disconnected', () => {
            emitter.connected = false;
            emitter.emit('disconnected');
        });

        client.on('expired', () => {
            emitter.connected = false;
            emitter.emit('expired');
        });

        emitter.__client = client;
        client.connect();
    };

    emitter.on('expired', () => {
        connect();
    });

    connect();
    return emitter;
};

export = beacon;

