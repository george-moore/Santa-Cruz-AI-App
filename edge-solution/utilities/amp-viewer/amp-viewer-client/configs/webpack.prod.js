const webpack = require('webpack');
const path = require('path');
const BaseConfig = require('./webpack.base.js');

module.exports = () => {
    const context = path.resolve(__dirname, '..');
    const config = BaseConfig(context);

    config.mode = 'production';
    config.cache = false; // Fresh
    config.output.publicPath = '/client_dist/';

    process.env.BABEL_ENV = 'production';
    process.env.NODE_ENV = 'production';

    config.plugins.unshift(
        new webpack.DefinePlugin({ PRODUCTION: JSON.stringify(true) })
    );

    config.devtool = 'source-map';

    return config;
};
