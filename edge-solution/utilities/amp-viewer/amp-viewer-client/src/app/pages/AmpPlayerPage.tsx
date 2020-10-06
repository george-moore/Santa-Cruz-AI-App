import * as React from 'react';
import { Grid, Message, Dimmer, Loader } from 'semantic-ui-react';
import { AmsStore } from '../stores';
import { AmpPlayer } from '../components/AmpPlayer';
import { observer, inject } from 'mobx-react';
import moment from 'moment';
import { parse as qsParse } from 'query-string';
import { bind } from '../../utils';

interface IAmpPlayerPage {
    amsStore: AmsStore;
    location: any;
}

interface IAmpPlayerPageState {
    streamingStartTime: string;
    streamingDuration: number;
    videoLoaded: boolean;
}

@inject('amsStore') @observer
export class AmpPlayerPage extends React.Component<IAmpPlayerPage, IAmpPlayerPageState> {
    constructor(props: any, context?: any) {
        super(props, context);

        this.state = {
            streamingStartTime: '',
            streamingDuration: 0,
            videoLoaded: false
        };
    }

    public async componentDidMount() {
        const {
            amsStore,
            location
        } = this.props;

        if (location.search) {
            const query = qsParse(location.search);
            if (query?.an) {
                const assetName = query.an as string;
                const streamingStartTime = (moment.utc(query.st as string, moment.ISO_8601, true) || moment.utc(0, moment.ISO_8601, true)).format('YYYY-MM-DDTHH:mm:ss[Z]');
                const streamingDuration = Number(query.du) || 60;

                this.setState({
                    streamingStartTime,
                    streamingDuration
                });

                await amsStore.createAmsStreamingLocator(assetName);
            }
        }
    }

    public render() {
        const {
            amsStore
        } = this.props;

        const {
            streamingStartTime
        } = this.state;

        const isError = amsStore.streamingLocatorError !== '';

        const dateHeader = isError
            ? 'Video Playback Error'
            : moment.utc(streamingStartTime, moment.ISO_8601, true).format('dddd, MMMM Do YYYY h:mm:ss a');

        return (
            <Grid style={{ padding: '5em 5em' }}>
                <Grid.Row>
                    <Grid.Column>
                        <Message size="huge" color={isError ? 'yellow' : 'grey'}>
                            <Message.Header>{`${dateHeader} UTC`}</Message.Header>
                            <p />
                            {
                                isError
                                    ? this.addLineBreaks(amsStore.streamingLocatorError)
                                    : (
                                        this.getAmpPlayerComponent()
                                    )
                            }
                        </Message>
                    </Grid.Column>
                </Grid.Row>
            </Grid>
        );
    }

    private getAmpPlayerComponent() {
        const {
            amsStore
        } = this.props;

        const {
            streamingStartTime,
            streamingDuration
        } = this.state;

        const sourceItem = amsStore.streamingLocatorFormats.find((item) => item.protocol === 'SmoothStreaming');
        if (sourceItem) {
            return (
                <AmpPlayer
                    sourceUrl={sourceItem.streamingLocatorUrl}
                    startTime={streamingStartTime}
                    duration={streamingDuration}
                    onVideoStarted={this.onVideoStarted}
                    onVideoEnded={this.onVideoEnded}
                    onVideoError={this.onVideoError}
                />
            );
        }

        return null;
    }

    @bind
    private onVideoLoaded() {
        this.setState({
            videoLoaded: true
        });
    }

    @bind
    private onVideoStarted() {
        return;
    }

    @bind
    private onVideoEnded() {
        return;
    }

    @bind
    private onVideoError(errorMessage: string) {
        const {
            amsStore
        } = this.props;

        amsStore.setStreamingLocatorError(errorMessage);
    }

    private addLineBreaks(text: string) {
        return text.split('\n').map((chunk, index) => (
            <p key={index}>{chunk}</p>
        ));
    }
}
