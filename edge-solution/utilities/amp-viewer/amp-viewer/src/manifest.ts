import { ComposeManifest } from 'spryly';

const DefaultPort = 8094;
const PORT = process.env.PORT || process.env.port || process.env.PORT0 || process.env.port0 || DefaultPort;

// @ts-ignore
export function manifest(config?: any): ComposeManifest {
    return {
        server: {
            port: PORT,
            app: {
                slogan: 'AMP client demo service'
            }
        },
        services: [
            './services'
        ],
        plugins: [
            ...[
                {
                    plugin: '@hapi/inert'
                }
            ],
            ...[
                {
                    plugin: './plugins'
                }
            ],
            ...[
                {
                    plugin: './apis'
                }
            ]
        ]
    };
}
