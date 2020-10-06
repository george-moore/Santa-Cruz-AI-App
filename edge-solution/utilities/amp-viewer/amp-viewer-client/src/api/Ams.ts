import { FetchResponse, fetchHelper } from './FetchHelper';

export function postCreateAmsStreamingLocatorApi(assetName: string): Promise<FetchResponse> {
    return fetchHelper(`/api/v1/ams/account/streaminglocator`,
        {
            method: 'POST',
            credentials: 'same-origin',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            },
            body: JSON.stringify({
                assetName
            })
        });
}
