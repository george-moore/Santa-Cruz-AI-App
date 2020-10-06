import { action, observable, computed } from 'mobx';
import { DataStore, StoreProvider, StoreEvents } from '.';
import { bind } from '../../utils';

export class BusyStore implements DataStore {
    public static displayName = 'busyStore';

    private static busyDelayTime = 350;
    private static minimumBusyTime = 1500;

    private busyCount: number = 0;
    private transitionToBusyTime: number = undefined;

    @observable
    private _isBusy = false;

    @computed
    public get isBusy() {
        return this._isBusy;
    }

    public initialize(storeProvider: StoreProvider) {
        storeProvider.on(StoreEvents.Busy, this.onBusy);
    }

    @action
    private setBusy(busy: boolean) {
        this._isBusy = busy;
    }

    @bind @action
    private onBusy(isBusy: boolean) {
        if (isBusy) {
            if (++this.busyCount === 1 && !this._isBusy) {

                setTimeout(() => {
                    if (this.busyCount > 0) {
                        this.setBusy(true);
                        this.transitionToBusyTime = Date.now();
                    }
                }, BusyStore.busyDelayTime);
            }
        }
        else {
            if (this.busyCount === 0) {
                throw new Error('Assymetric calls to onBusy');
            }
            if (--this.busyCount === 0) {
                const currentTime = Date.now();
                const timeSinceBusy = currentTime - this.transitionToBusyTime;
                if (timeSinceBusy >= BusyStore.minimumBusyTime) {
                    this._isBusy = false;
                }
                else {
                    setTimeout(() => {
                        if (this.busyCount === 0) {
                            this.setBusy(false);
                        }
                    }, BusyStore.minimumBusyTime - timeSinceBusy);
                }
            }
        }
    }
}
