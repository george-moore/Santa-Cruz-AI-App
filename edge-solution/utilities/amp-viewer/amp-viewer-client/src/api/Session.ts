import { FetchResponse, fetchHelper } from './FetchHelper';
import moment from 'moment';

export function fetchUserSession(): Promise<FetchResponse> {
    return fetchHelper('/api/v1/auth/user',
        {
            method: 'GET',
            credentials: 'same-origin',
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
            }
        }
    );
}
