import { service, inject } from 'spryly';
import { Server } from '@hapi/hapi';
import { ConfigService } from '../services/config';
import * as msRestNodeAuth from '@azure/ms-rest-nodeauth';
import { AzureMediaServices } from '@azure/arm-mediaservices';
import { v4 as uuidV4 } from 'uuid';

interface IAmsRequestParams {
    amsClient: AzureMediaServices;
    accountName: string;
    resourceGroup: string;
    assetName: string;
}

export interface IAmsResponse {
    statusMessage: string;
    data: any;
}

@service('ams')
export class AmsService {
    @inject('$server')
    private server: Server;

    @inject('config')
    private config: ConfigService;

    private amsAccount = {
        amsAadClientId: '',
        amsAadSecret: '',
        amsAadTenantId: '',
        amsArmAadAudience: '',
        amsArmEndpoint: '',
        amsAadEndpoint: '',
        amsSubscriptionId: '',
        amsResourceGroup: '',
        amsAccountName: ''
    };

    public async init(): Promise<void> {
        this.server.log(['AmsService', 'info'], 'initialize');

        let amsArmAadAudience = this.config.get('amsArmAadAudience') || '';
        let amsArmEndpoint = this.config.get('amsArmEndpoint') || '';
        let amsAadEndpoint = this.config.get('amsAadEndpoint') || '';

        if (amsArmAadAudience.slice(-1) !== '/') {
            amsArmAadAudience = `${amsArmAadAudience}/`;
        }

        if (amsArmEndpoint.slice(-1) !== '/') {
            amsArmEndpoint = `${amsArmEndpoint}/`;
        }

        if (amsAadEndpoint.slice(-1) !== '/') {
            amsAadEndpoint = `${amsAadEndpoint}/`;
        }

        this.amsAccount = {
            amsAadClientId: this.config.get('amsAadClientId') || '',
            amsAadSecret: this.config.get('amsAadSecret') || '',
            amsAadTenantId: this.config.get('amsAadTenantId') || '',
            amsArmAadAudience,
            amsArmEndpoint,
            amsAadEndpoint,
            amsSubscriptionId: this.config.get('amsSubscriptionId') || '',
            amsResourceGroup: this.config.get('amsResourceGroup') || '',
            amsAccountName: this.config.get('amsAccountName') || ''
        };
    }

    // @ts-ignore (startTime)
    public async postCreateAmsStreamingLocator(assetName: string): Promise<IAmsResponse> {
        let amsResponse = {
            statusMessage: 'SUCCESS',
            data: undefined
        };

        try {
            amsResponse = await this.ensureAmsClient();
            if (amsResponse.statusMessage !== 'SUCCESS') {
                return amsResponse;
            }

            const amsRequestParams: IAmsRequestParams = {
                amsClient: amsResponse.data.amsClient,
                accountName: amsResponse.data.accountName,
                resourceGroup: amsResponse.data.resourceGroup,
                assetName
            };

            amsResponse = await this.listStreamingLocators(amsRequestParams);
            if (amsResponse.statusMessage !== 'SUCCESS') {
                return amsResponse;
            }

            if (amsResponse.data?.streamingLocators.length > 0) {
                amsResponse = await this.getStreamingLocator(amsRequestParams, amsResponse.data.streamingLocators[0].name);
            }
            else {
                amsResponse = await this.createStreamingLocators(amsRequestParams);
                if (amsResponse.statusMessage !== 'SUCCESS') {
                    return amsResponse;
                }

                amsResponse = await this.getStreamingLocator(amsRequestParams, amsResponse.data.name);
            }
        }
        catch (ex) {
            this.server.log(['AmsService', 'error'], `Error while creating streaming locator: ${ex.message}`);
            amsResponse.statusMessage = 'ERROR_UNKNOWN';
        }

        return amsResponse;
    }

    private async ensureAmsClient(): Promise<IAmsResponse> {
        this.server.log(['AmsService', 'info'], 'initialize');

        const amsResponse = {
            statusMessage: 'SUCCESS',
            data: {}
        };

        try {
            if (this.amsAccount.amsAccountName === '') {
                return {
                    statusMessage: 'ERROR_NO_AMS_ACCOUNT',
                    data: ''
                };
            }

            const loginCredentials = await msRestNodeAuth.loginWithServicePrincipalSecret(
                this.amsAccount.amsAadClientId,
                this.amsAccount.amsAadSecret,
                this.amsAccount.amsAadTenantId, {
                environment: {
                    activeDirectoryResourceId: this.amsAccount.amsArmAadAudience,
                    resourceManagerEndpointUrl: this.amsAccount.amsArmEndpoint,
                    activeDirectoryEndpointUrl: this.amsAccount.amsAadEndpoint
                }
            });

            const amsClient = new AzureMediaServices(loginCredentials as any, this.amsAccount.amsSubscriptionId);

            amsResponse.data = {
                amsClient,
                resourceGroup: this.amsAccount.amsResourceGroup,
                accountName: this.amsAccount.amsAccountName
            };
        }
        catch (ex) {
            this.server.log(['AmsService', 'error'], `Error logging into AMS account: ${ex.message}`);

            amsResponse.statusMessage = 'ERROR_UNKNOWN';
        }

        return amsResponse;
    }

    private async getStreamingLocator(amsRequestParams: IAmsRequestParams, streamingLocatorName: string): Promise<IAmsResponse> {
        const response: IAmsResponse = {
            statusMessage: 'SUCCESS',
            data: []
        };

        try {
            const streamingEndpoint = await amsRequestParams.amsClient.streamingEndpoints.get(
                amsRequestParams.resourceGroup,
                amsRequestParams.accountName,
                'default');

            const streamingLocatorsListPathsResponse =
                await amsRequestParams.amsClient.streamingLocators.listPaths(
                    amsRequestParams.resourceGroup,
                    amsRequestParams.accountName,
                    streamingLocatorName);

            response.data = streamingLocatorsListPathsResponse.streamingPaths.map((streamingPath) => {
                return {
                    protocol: streamingPath.streamingProtocol,
                    streamingLocatorUrl: `https://${streamingEndpoint.hostName}/${streamingPath.paths[0]}`
                };
            });
        }
        catch (ex) {
            this.server.log(['AmsService', 'error'], `Error getting listing streaming locator paths: ${ex.message}`);
            response.statusMessage = 'ERROR_ACCESSING_STREAMING_LOCATOR';
        }

        return response;
    }

    private async listStreamingLocators(amsRequestParams: IAmsRequestParams): Promise<IAmsResponse> {
        const response: IAmsResponse = {
            statusMessage: 'SUCCESS',
            data: {}
        };

        try {
            response.data = await amsRequestParams.amsClient.assets.listStreamingLocators(
                amsRequestParams.resourceGroup,
                amsRequestParams.accountName,
                amsRequestParams.assetName);
        }
        catch (ex) {
            this.server.log(['AmsService', 'error'], `The specified asset (${amsRequestParams.assetName}) was not found: ${ex.message}`);
            response.statusMessage = 'ERROR_ASSET_NOT_FOUND';
        }

        return response;
    }

    private async createStreamingLocators(amsRequestParams: IAmsRequestParams): Promise<IAmsResponse> {
        const response: IAmsResponse = {
            statusMessage: 'SUCCESS',
            data: []
        };

        try {
            response.data = await amsRequestParams.amsClient.streamingLocators.create(
                amsRequestParams.resourceGroup,
                amsRequestParams.accountName,
                `locator_${uuidV4()}`,
                {
                    assetName: amsRequestParams.assetName,
                    streamingPolicyName: 'Predefined_ClearStreamingOnly'
                });
        }
        catch (ex) {
            this.server.log(['AmsService', 'error'], `Error while creating streaming locator urls: ${ex.message}`);
            response.statusMessage = 'ERROR_STREAMING_LOCATOR';
        }

        return response;
    }
}
