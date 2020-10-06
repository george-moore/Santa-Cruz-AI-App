import 'whatwg-fetch';

export class FetchResponse {
    public statusCode: number;
    public message: string;
    public body: any;
    public get succeeded() {
        return (this.statusCode >= 200 && this.statusCode < 300);
    }

    constructor(statusCode: number, message: string) {
        this.statusCode = statusCode;
        this.message = message;
    }
}

export async function fetchHelper(url, options): Promise<FetchResponse> {
    return fetch(url, options)
        .then(response => {
            const restResponse = new FetchResponse(response.status, response.statusText);

            if (response.status !== 204 && response.status !== 205) {
                return response.text()
                    .then(text => {
                        try {
                            restResponse.body = JSON.parse(text);
                        } catch (e) {
                            restResponse.body = text;
                        }

                        return restResponse;
                    });
            }

            return restResponse;
        }, error => {
            throw error;
        });
}
