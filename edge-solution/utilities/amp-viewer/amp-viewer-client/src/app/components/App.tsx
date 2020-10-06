import * as React from 'react';
import { Switch, Route, Redirect } from 'react-router-dom';
import { Menu, Grid } from 'semantic-ui-react';
import { parse as qsParse } from 'query-string';
import { ErrorDialog } from './ErrorDialog';
import { AmpPlayerPage } from '../pages/AmpPlayerPage';

interface IAppProps {
    location: any;
    history: any;
}

export class AppComponent extends React.Component<IAppProps, {}> {
    public componentDidMount() {
        const {
            history,
            location
        } = this.props;

        let redirectPath = location.pathname;

        if (location.search) {
            const query = qsParse(location.search);

            redirectPath = query.redirectPath || `${redirectPath}${location.search}`;
        }

        history.push(redirectPath);
    }

    public render() {
        const {
            location
        } = this.props;

        return (
            <div>
                {/* {PRODUCTION ? null : <DevTools />} */}
                <Menu fixed="top" inverted color="grey" style={{ padding: '0em 5em' }} />
                <Grid>
                    <Grid.Column>
                        <Switch>
                            <Route exact path="/" component={AmpPlayerPage} />
                            <Route exact path="/ampplayer" component={AmpPlayerPage} />
                            <Redirect from={location.pathname} to="/" />
                            {this.props.children}
                        </Switch>
                        <ErrorDialog />
                    </Grid.Column>
                </Grid>
                <Menu fixed="bottom" inverted color="grey" style={{ padding: '1em 5em' }} />
            </div>
        );
    }
}
