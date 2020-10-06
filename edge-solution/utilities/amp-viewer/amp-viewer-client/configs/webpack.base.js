const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const CopyPlugin = require('copy-webpack-plugin');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');

module.exports = (context) => {
    const config = {
        context,

        resolve: {
            extensions: ['.js', '.ts', '.tsx']
        },

        entry: {
            index: path.resolve(context, './src/index')
        },

        output: {
            path: path.resolve(context, './client_dist'),
            filename: '[name].js'
        },

        optimization: {
            splitChunks: {
                cacheGroups: {
                    commons: {
                        chunks: 'initial',
                        minChunks: 2,
                        maxInitialRequests: 5, // The default limit is too small to showcase the effect
                        minSize: 0 // This is example is too small to create commons chunks
                    },
                    vendor: {
                        test: /node_modules/,
                        chunks: 'initial',
                        name: 'vendor',
                        priority: 10,
                        enforce: true
                    }
                }
            }
        },

        performance: {
            maxEntrypointSize: 650000,
            maxAssetSize: 650000
        },

        devtool: 'source-map',

        module: {
            rules: [
                {
                    test: /\.(ts|tsx)$/,
                    exclude: /node_modules/,
                    use: {
                        loader: 'awesome-typescript-loader',
                        options: {
                            useBabel: true
                        }
                    }
                },
                {
                    test: /\.(css|scss)$/,
                    include: [
                        /node_modules/,
                        path.resolve(context, './src/styles')
                    ],
                    use: [
                        {
                            loader: MiniCssExtractPlugin.loader,
                        },
                        'css-loader'
                    ]
                },
                {
                    test: /\.woff$|\.ttf$|\.wav$|\.mp3$/,
                    loader: 'file-loader?name=/assets/[name].[ext]'
                },
                // Loading glyphicons => https://github.com/gowravshekar/bootstrap-webpack
                // Using here url-loader and file-loader
                {
                    test: /\.(woff|woff2)(\?v=\d+\.\d+\.\d+)?$/,
                    loader: 'url-loader?limit=10000&mimetype=application/font-woff'
                },
                {
                    test: /\.ttf(\?v=\d+\.\d+\.\d+)?$/,
                    loader: 'url-loader?limit=10000&mimetype=application/octet-stream'
                },
                {
                    test: /\.jpe?g$|\.ico$|\.gif$|\.png$|\.svg$/,
                    use: [{
                        loader: 'url-loader',
                        options: {
                            limit: 25000,
                            name: '/assets/[hash]-[name].[ext]'
                        }
                    }]
                },
                {
                    test: /\.svg(\?v=\d+\.\d+\.\d+)?$/,
                    loader: 'url-loader?limit=10000&mimetype=image/svg+xml'
                },
                {
                    test: /\.eot(\?v=\d+\.\d+\.\d+)?$/,
                    loader: 'file-loader'
                },
                {
                    type: 'javascript/auto',
                    test: /\.json$/,
                    use: [
                        {
                            loader: 'file-loader',
                            options: {
                                name: './plugin-config/[name].[ext]'
                            }
                        }
                    ]
                }]
        },

        plugins: [
            // Generate index.html in /client_dist => https://github.com/ampedandwired/html-webpack-plugin
            new HtmlWebpackPlugin({
                title: 'AMP Client',
                template: path.resolve(context, './src/index.html'),
                hash: true
            }),
            new CopyPlugin({
                patterns: [
                    {
                        from: './assets',
                        to: 'assets',
                        globOptions: {
                            ignore: ['__mocks__/**', 'index.ts']
                        }
                    }
                ]
            }),
            new MiniCssExtractPlugin({
                filename: '[name].[hash].css'
            })
        ]
    };

    return config;
};
