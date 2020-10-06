import 'babel-polyfill';
import * as React from 'react';
import * as ReactDOM from 'react-dom';
// tslint:disable-next-line:no-implicit-dependencies
import { AppContainer } from 'react-hot-loader';
import { appProvider } from './provider';
import { configure } from 'mobx';
import { createStoreProvider } from './app/stores';

// Don't allow MobX state mutation without a MobX action
configure({
    enforceActions: 'observed'
});

// tslint:disable-next-line:variable-name
const render = (Component) => {
    ReactDOM.render(
        (
            <AppContainer>
                <Component />
            </AppContainer>
        ),
        document.getElementById('app')
    );
};

async function start() {
    try {
        const storeProvider = createStoreProvider();

        render(appProvider.bind(null, { storeProvider, ...storeProvider.stores }));

        if (module.hot) {
            module.hot.accept('./provider', () => {
                render(appProvider.bind(null, { storeProvider }));
            });
        }
    }
    catch (error) {
        // tslint:disable-next-line:no-console
        console.log(`['startup', 'error'], 👹 Error starting react client: ${error.message}`);
    }
}

start();
