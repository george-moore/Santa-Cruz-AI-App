import { inject, RoutePlugin, route } from 'spryly';
import { Server, Request, ResponseToolkit } from '@hapi/hapi';
import { AmsService } from '../services/ams';
import { badRequest as boomBadRequest } from '@hapi/boom';

export class AmsRoutes extends RoutePlugin {
    @inject('$server')
    private server: Server;

    @inject('ams')
    private ams: AmsService;

    @route({
        method: 'POST',
        path: '/api/v1/ams/account/streaminglocator',
        options: {
            tags: ['ams'],
            description: 'Create streaming locator'
        }
    })
    // @ts-ignore (h)
    public async postCreateAmsStreamingLocator(request: Request, h: ResponseToolkit) {
        this.server.log(['AmsRoutes', 'info'], 'postCreateAmsStreamingLocator');

        const assetName = (request.payload as any)?.assetName;
        if (!assetName) {
            throw boomBadRequest('Missing assetName parameter');
        }

        const amsResponse = await this.ams.postCreateAmsStreamingLocator(assetName);

        return h.response(amsResponse).code((!Array.isArray(amsResponse.data) || amsResponse.data.length === 0) ? 401 : 201);
    }
}
