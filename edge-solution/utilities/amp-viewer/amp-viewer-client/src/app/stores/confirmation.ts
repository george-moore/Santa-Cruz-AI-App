import { action, observable, computed } from 'mobx';
import { DataStore, StoreProvider } from '.';

export class ConfirmationStore implements DataStore {
    public static displayName = 'confirmationStore';

    @observable
    public _shouldShow: boolean = false;

    @observable
    public title: string;

    @observable
    public message: string;

    @observable
    public confirmAction: string;

    @observable
    public confirmCallback: () => void;

    public initialize(storeProvider: StoreProvider) {
        //
    }

    @computed
    public get shouldShow() {
        return this._shouldShow;
    }

    public set shouldShow(value) {
        this._shouldShow = value;
    }

    @action
    public showConfirmation(title: string, message: string, confirmAction: string, confirmCallback: () => void) {
        this._shouldShow = true;
        this.title = title;
        this.message = message;
        this.confirmAction = confirmAction;
        this.confirmCallback = confirmCallback;
    }
}
