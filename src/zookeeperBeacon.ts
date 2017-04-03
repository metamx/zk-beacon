import { EventEmitter } from 'events';
import * as zookeeper from 'node-zookeeper-client';
import * as uuid from 'uuid';
import { BeaconEvents } from './beaconEvents';

export interface ZookeeperBeaconOptions {
    servers : string;
    path : string;
    payload : any;
    spinDelay? : number;
}

export class ZookeeperBeacon extends EventEmitter {
    private id : string;
    private connected : boolean;

    private config : ZookeeperBeaconOptions;
    private client : zookeeper.Client;

    constructor(options : ZookeeperBeaconOptions) {
        super();
        this.config = options;

        this.id = uuid.v1();
        this.connected = false;

        this.on(BeaconEvents.EXPIRED, () => {
            if (this.config.spinDelay) {
                setTimeout(() => {
                    this.connect();
                }, this.config.spinDelay);
            } else {
                this.connect();
            }
        });

        this.connect();
    }

    private connect = () => {
        if (this.client) {
            this.client.removeAllListeners();
        }

        this.client = zookeeper.createClient(this.config.servers, {
            retries: 3,
            sessionTimeout: 15000
        });

        this.client.on('connected', () => {
            this.connected = true;
            this.emit(BeaconEvents.CONNECTED);

            this.client.mkdirp(
                this.config.path,
                (err) => {
                    if (err) {
                        this.emit(BeaconEvents.ERROR,
                            new Error(`Failed to create path: ${this.config.path} due to: ${err}.`));
                        return;
                    }
                    this.client.create(
                        this.config.path + '/' + this.id,
                        new Buffer(JSON.stringify(this.config.payload)),
                        zookeeper.CreateMode.EPHEMERAL,
                        (createErr) => {
                            if (createErr && ((createErr as any).getCode() !== zookeeper.Exception.NODE_EXISTS)) {
                                this.emit(BeaconEvents.ERROR,
                                    new Error(`Failed to create node: ${this.config.path}/${this.id} due to: ${err}.`));
                                return;
                            }
                            this.emit(BeaconEvents.CREATED, this.id);
                            return;
                        }
                    );
                    return;
                }
            );
        });

        this.client.on('disconnected', () => {
            this.connected = false;
            this.emit(BeaconEvents.DISCONNECTED);
        });

        this.client.on('expired', () => {
            this.connected = false;
            this.emit(BeaconEvents.EXPIRED);
        });

        this.client.connect();
    }
}
