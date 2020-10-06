import { RoutePlugin, route } from 'spryly';
import { Request, ResponseToolkit } from '@hapi/hapi';
import {
    dirname as pathDirname,
    resolve as pathResolve
} from 'path';

const rootDirectory = pathResolve(pathDirname(require.main.filename), '..');

export class StaticRoutes extends RoutePlugin {
    @route({
        method: 'GET',
        path: '/favicon.ico',
        options: {
            tags: ['static'],
            description: 'The static favicon',
            handler: {
                file: pathResolve(rootDirectory, 'static', 'favicons', 'favicon.ico')
            }
        }
    })
    // @ts-ignore (request, h)
    public async getFavicon(request: Request, h: ResponseToolkit) {
        return;
    }

    @route({
        method: 'GET',
        path: '/favicons/{path*}',
        options: {
            tags: ['static'],
            description: 'The static assets',
            handler: {
                directory: {
                    path: pathResolve(rootDirectory, 'static', 'favicons'),
                    index: false
                }
            }
        }
    })
    // @ts-ignore (request , h)
    public async getStatic(request: Request, h: ResponseToolkit) {
        return;
    }
}
