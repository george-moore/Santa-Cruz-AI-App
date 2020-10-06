import { action, observable, runInAction } from 'mobx';
import { DataStore, StoreEvents, ErrorTypes } from '.';
import { EventEmitter2 } from 'eventemitter2';
import { postCreateAmsStreamingLocatorApi } from '../../api/Ams';

const genericError = `Sorry, an unknown error occurred, try again after rebooting your device`;

export class AmsStore implements DataStore {
    public static displayName = 'amsStore';

    @observable
    public loading: boolean = true;

    @observable
    public streamingLocatorFormats: any = [];

    @observable
    public streamingLocatorError: string = '';

    private _emitter = new EventEmitter2();

    public get emitter() {
        return this._emitter;
    }

    @action
    public async createAmsStreamingLocator(assetName: string) {
        let succeeded = false;

        if (!assetName) {
            this.emitError('Error', `Missing assetName (an) param in url string`);
            return;
        }

        runInAction(() => {
            this.loading = true;
        });

        try {
            const response = await postCreateAmsStreamingLocatorApi(assetName);
            if (response.succeeded && response.body.statusMessage === 'SUCCESS') {
                runInAction('postCreateAmsStreamingLocator', () => {
                    this.streamingLocatorFormats = response.body.data;
                });
            }
            else {
                let errorMessage = response.message;

                const statusMessage = response.body.statusMessage || '';
                switch (statusMessage) {
                    case 'ERROR_NO_AMS_ACCOUNT':
                        errorMessage = 'No registered Azure Media account was found.\nPlease register the AMS account that was used to create the cloud recordings on the Azure Media service.\nYou can get the registration information from the Azure Portal.';
                        break;

                    case 'ERROR_ASSET_NOT_FOUND':
                        errorMessage = 'The Azure Media asset specified in the URL was not found.\nThe link may be old or the Azure Media recording asset may no longer exists in your AMS account.';
                        break;

                    case 'ERROR_ACCESSING_STREAMING_LOCATOR':
                        errorMessage = 'An error occurred while trying to access an existing streaming locator for the specified Azure Media asset.\nThe link may be old or the Azure Media recording asset may no longer exists in your AMS account.';
                        break;

                    case 'ERROR_CREATING_STREAMING_LOCATOR':
                        errorMessage = 'An error occured while trying to create a streaming resource for the Azure Media asset specified in the URL.\nPlease check your registered AMS account settings and verify that they match the information from in the Azure Portal.';
                        break;

                    case 'ERROR_UNKNOWN':
                        errorMessage = 'An error occured while trying to access the video link specified in the URL.\nPlease check your registered AMS account settings and verify that they match the information from in the Azure Portal.';
                        break;
                }
                // this.emitError('Media Playback Error', errorMessage);
                runInAction('streamingLocatorError', () => {
                    this.streamingLocatorError = errorMessage;
                });
            }

            succeeded = response.succeeded;
        }
        catch (error) {
            this.emitError('Error', error);
        }

        runInAction(() => {
            this.loading = false;
        });

        return succeeded;
    }

    @action
    public setStreamingLocatorError(error: string) {
        runInAction('streamingLocatorError', () => {
            this.streamingLocatorError = error;
        });
    }

    @action
    public clearStreamingLocatorError() {
        runInAction('streamingLocatorError', () => {
            this.streamingLocatorError = '';
        });
    }

    private emitError(title: string, message: string) {
        this.emitter.emit(StoreEvents.Error, {
            result: false,
            type: ErrorTypes.MessageError,
            error: {
                title,
                message
            }
        });
    }
}
