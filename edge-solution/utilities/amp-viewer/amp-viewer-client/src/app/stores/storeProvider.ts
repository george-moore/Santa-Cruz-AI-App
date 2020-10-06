import { EventEmitter2, Listener } from 'eventemitter2';
import { bind } from '../../utils';
import * as Stores from '.';

export interface DataStore {
    initialize?: (storeProvider: StoreProvider) => void;
    emitter?: EventEmitter2;
}

export enum StoreEvents {
    Error = 'Error',
    Busy = 'Busy'
}

export interface StoreProvider extends EventEmitter2 {
    [key: string]: any;
    stores: any;
}

export function createStoreProvider(): StoreProvider {
    return new StoreCollection(Stores.default);
}

class StoreCollection extends EventEmitter2 implements StoreProvider {
    private _stores: any = {};

    constructor(StoresImports: any) {
        super();

        for (const Store of StoresImports) {
            const store = new Store();
            this[Store.displayName] = store;
            this._stores[Store.displayName] = store;
            if (store.initialize) {
                store.initialize(this);
            }
            if (store.emitter) {
                store.emitter.onAny(this.onStoreEvent);
            }
        }
    }

    public get stores() {
        return this._stores;
    }

    public on(event: string | string[], listener: Listener): this {
        // const events: string[] = (typeof event === 'string') ? [event] : event;

        // const validMesssages = Object.keys(StoreEvents);
        // for (const eventName of events) {
        //     if (!validMesssages.includes(eventName)) {
        //         throw new Error('Invalid event name');
        //     }
        // }

        return super.on(event, listener);
    }

    @bind
    private onStoreEvent(event: string, ...values: any[]) {
        this.emit(event, ...values);
    }
}
