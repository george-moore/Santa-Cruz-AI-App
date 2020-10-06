import { action, observable, computed } from 'mobx';
import { FetchResponse } from '../../api/FetchHelper';
import { StoreProvider, StoreEvents, DataStore } from '.';
import { bind } from '../../utils';

export enum ErrorTypes {
    FetchError = 'FetchError',
    ExceptionError = 'ExceptionError',
    MessageError = 'MessageErorr'
}

export interface IErrorResult {
    result: boolean;
    type: ErrorTypes;
    error: any;
}

export class ErrorStore implements DataStore {
    public static displayName = 'errorStore';

    @observable
    public _shouldShow: boolean = false;

    @observable
    public title: string = 'Error';

    @observable
    public message: string;

    @computed
    public get shouldShow() {
        return this._shouldShow;
    }

    public set shouldShow(value) {
        this._shouldShow = value;
    }

    @action
    public showFetchError(fetchResponse: FetchResponse) {
        this.shouldShow = true;
        this.message = `HTTP error code ${fetchResponse.statusCode}: ${fetchResponse.message}`;
    }

    @action
    public showExceptionError(error: Error) {
        this.shouldShow = true;
        this.message = `Unexpected error: ${error.message}`;
    }

    @action
    public showError(title: string, message: string) {
        this.shouldShow = true;

        this.title = title || 'Unexpected error';
        this.message = message;
    }

    public initialize(storeProvider: StoreProvider) {
        storeProvider.on(StoreEvents.Error, this.onError);
    }

    @bind
    private onError(errorResult: IErrorResult) {
        switch (errorResult.type) {
            case ErrorTypes.FetchError:
                this.showFetchError(errorResult.error);
                break;

            case ErrorTypes.ExceptionError:
                this.showExceptionError(errorResult.error);
                break;

            case ErrorTypes.MessageError:
                this.showError(errorResult?.error?.title, errorResult?.error?.message || 'An unknown error occurred');
                break;
        }
    }
}
