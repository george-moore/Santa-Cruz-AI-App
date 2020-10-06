import * as React from 'react';
import { Provider } from 'mobx-react';
import { Router, Route } from 'react-router-dom';
import { AppComponent } from './app/components/App';
import { createBrowserHistory } from 'history';

const history = createBrowserHistory();

// This provider needs to be imported from a separate file to enable hot loading
export const appProvider = (stores) => {
    return (
        <Provider {...stores}>
            <Router history={history}>
                <Route path="/:filter?" component={AppComponent} />
            </Router>
        </Provider>
    );
};
