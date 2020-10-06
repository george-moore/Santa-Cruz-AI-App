import * as React from 'react';
import { Dimmer, Loader } from 'semantic-ui-react';
import { bind } from '../../utils';
import moment from 'moment';

interface IAmpPlayerProps {
    sourceUrl: string;
    startTime: string;
    duration: number;
    skin?: string;
    onVideoStarted: () => void;
    onVideoEnded: () => void;
    onVideoError: (error: string) => void;
}

interface IAmpPlayerState {
    ampPlayer: any;
}

const ampPlayerStyle = 'https://amp.azure.net/libs/amp/2.3.4/skins/###SKIN/azuremediaplayer.min.css';
const ampPlayerUrl = 'https://amp.azure.net/libs/amp/2.3.4/azuremediaplayer.min.js';

export class AmpPlayer extends React.Component<IAmpPlayerProps, IAmpPlayerState> {
    public static defaultProps = {
        skin: 'amp-default'
    };

    private videoElement: any = React.createRef();

    constructor(props: any, context?: any) {
        super(props, context);

        this.state = {
            ampPlayer: null
        };
    }

    public setPlayerSize(clientRect: any) {
        const {
            ampPlayer
        } = this.state;

        if (ampPlayer) {
            ampPlayer.c.width = clientRect.width;
            ampPlayer.c.height = clientRect.height;
        }
    }

    public async componentDidMount() {
        const {
            sourceUrl,
            startTime,
            skin
        } = this.props;

        await this.loadScript(ampPlayerUrl, skin);

        const ampOptions = {
            techOrder: ['azureHtml5JS', 'html5FairPlayHLS', 'html5'],
            wallClockDisplaySettings: {
                enabled: true,
                useLocalTimeZone: true
            },
            nativeControlsForTouch: false,
            autoplay: false,
            controls: true,
            fluid: true
            // width: '640',
            // height: '400',
        };

        this.createAmpPlayer(ampOptions);
    }

    public componentWillUnmount() {
        const {
            ampPlayer
        } = this.state;

        if (ampPlayer) {
            ampPlayer.dispose();
        }

        this.setState({
            ampPlayer: null
        });
    }

    public render() {
        const {
            ampPlayer
        } = this.state;

        return (
            <div className="amp-player-container">
                <Dimmer active={!ampPlayer} inverted>
                    <Loader size="large">
                        <p>Connecting to video stream...</p>
                    </Loader>
                </Dimmer>
                <video
                    id="amp-player"
                    ref={this.videoElement}
                    className="azuremediaplayer amp-default-skin"
                    style={{ width: '100%' }}
                />
            </div>
        );
    }

    @bind
    private async loadScript(url: string, skin: string): Promise<void> {
        return new Promise((resolve) => {
            const link = document.createElement('link');
            link.rel = 'stylesheet';
            link.href = ampPlayerStyle.replace('###SKIN', skin);
            document.head.insertBefore(link, document.head.firstChild);

            const script = document.createElement('script');
            script.type = 'text/javascript';
            script.src = url;
            script.async = false;

            script.onload = () => {
                return resolve();
            };

            document.body.appendChild(script);
        });
    }

    private createAmpPlayer(options: any) {
        const {
            sourceUrl,
            startTime,
            duration,
            onVideoError
        } = this.props;

        try {
            const player = window['amp'](
                this.videoElement.current, options, () => {
                    player.addEventListener('playing', this.videoStarted);
                    player.addEventListener('ended', this.videoEnded);
                    player.addEventListener('error', this.videoError);

                    player.src([
                        {
                            src: `${sourceUrl}(starttime=${startTime},endtime=${moment(startTime).add(duration, 'seconds').toISOString()})`,
                            type: 'application/vnd.ms-sstr+xml',
                            // type: 'video/mp4',
                            disableUrlRewriter: false
                        }
                    ]);

                    // player.play();

                    this.setState({
                        ampPlayer: player
                    });
                });
        }
        catch (ex) {
            onVideoError(`An error occurred trying to create the Azure Media Player control: ${ex.message}`);
        }
    }

    @bind
    private videoStarted() {
        const {
            onVideoStarted
        } = this.props;

        onVideoStarted();
    }

    @bind
    private videoEnded() {
        const {
            onVideoEnded
        } = this.props;

        onVideoEnded();
    }

    @bind
    private videoError() {
        const {
            onVideoError
        } = this.props;

        const {
            ampPlayer
        } = this.state;

        const error = ampPlayer.error();
        const errorMessage = this.getAmpErrorMessageFromErrorCode(error.code);

        onVideoError(errorMessage);

        ampPlayer.dispose();

        this.setState({
            ampPlayer: null
        });
    }

    private getAmpErrorMessageFromErrorCode(errorCode: number): string {
        let errorMessage;

        // tslint:disable-next-line: no-bitwise
        switch (errorCode & 0x00FFFFFF) {
            // MEDIA_ERR_ABORTED
            case 1048576: // 0x0100000, abortedErrUnknown
            case 1048577: // 0x0100001, abortedErrNotImplemented
                errorMessage = 'The video content was aborted.';
                break;
            case 1048578: // 0x0100002, abortedErrHttpMixedContentBlocked
                errorMessage = 'The video content was aborted.\nIt may be due to mixed content (http:// vs. https://).';
                break;

            // MEDIA_ERR_NETWORK
            case 2097152: // 0x0200000, networkErrUnknown
                errorMessage = 'A network error occurred while trying to play the video content.';
                break;
            case 2097552: // 0x0200190, networkErrHttpBadUrlFormat
                errorMessage = 'An error occurred while playing the video content.';
                break;
            case 2097553: // 0x0200191, networkErrHttpUserAuthRequired
            case 2097555: // 0x0200193, networkErrHttpUserForbidden
            case 2097557: // 0x0200195, networkErrHttpNotAllowed
                errorMessage = 'An error occurred while playing the video content.\nAuthorization may be required.';
                break;
            case 2097556: // 0x0200194, networkErrHttpUrlNotFound
            case 2097562: // 0x020019A, networkErrHttpGone
                errorMessage = 'An error occurred while playing the video content.\nThe resource could not be found.';
                break;
            case 2097564: // 0x020019C, networkErrHttpPreconditionFailed
                errorMessage = 'An error occurred while playing the video content.';
                break;
            case 2097652: // 0x02001F4, networkErrHttpInternalServerFailure
                errorMessage = 'An error occurred while playing the video content.\nThere was an internal server error.';
                break;
            case 2097654: // 0x02001F6, networkErrHttpBadGateway
            case 2097655: // 0x02001F7, networkErrHttpServiceUnavailable
            case 2097656: // 0x02001F8, networkErrHttpGatewayTimeout
            case 2097752: // 0x0200258, networkErrTimeout
            case 2097753: // 0x0200259, networkErrErr
                errorMessage = 'An error occurred while playing the video content.\nThe resource could not be reached on the service.';
                break;

            // MEDIA_ERR_DECODE
            case 3145728: // 0x0300000, decodeErrUnknown
                errorMessage = 'An error occurred while playing the video content.\nThe content format caused an error.';
                break;

            // MEDIA_ERR_SRC_NOT_SUPPORTED
            case 4194304: // 0x0400000, srcErrUnknown
                errorMessage = 'An error occurred while playing the video content.\nThe content format is not supported.';
                break;
            case 4194305: // 0x0400001, srcErrParsePresentation
            case 4194306: // 0x0400003, srcErrUnsupportedPresentation
            case 4194307: // 0x0400004, srcErrInvalidSegment
                errorMessage = 'An error occurred while playing the video content.';
                break;

            // MEDIA_ERR_ENCRYPTED
            case 5242880: // 0x0500000, encryptErrUnknown
            case 5242881: // 0x0500001, encryptErrDecrypterNotFound
            case 5242882: // 0x0500002, encryptErrDecrypterInit
            case 5242883: // 0x0500003, encryptErrDecrypterNotSupported
            case 5242884: // 0x0500004, encryptErrKeyAcquire
            case 5242885: // 0x0500005, encryptErrDecryption
            case 5242886: // 0x0500006, encryptErrLicenseAcquire
                errorMessage = 'An error occurred while playing the video content.\nThe content encryption or license key caused an error.';
                break;

            // SRC_PLAYER_MISMATCH
            case 6291456: // 0x0600000, srcPlayerMismatchUnknown
                errorMessage = 'An error occurred while playing the video content.\nThe specified tech parameter cannot play the source content.';
                break;
            case 6291457: // 0x0600001, srcPlayerMismatchFlashNotInstalled
                errorMessage = 'An error occurred while playing the video content.\nThe Flash plugin is required to play this content.';
                break;
            case 6291458: // 0x0600002, srcPlayerMismatchSilverlightNotInstalled
                errorMessage = 'An error occurred while playing the video content.\nThe Silverlight plugin is required to play this content.';
                break;
            case 6291459: // 0x0600003
                errorMessage = 'An error occurred while playing the video content.\nBoth the Flash plugin and Silverlight plugin are specified but are not installed.';
                break;

            // Unknown errors
            case 267386880: // 0x0FF00000, errUnknown
            default:
                errorMessage = 'An unknown error occurred.';
                break;
        }

        return errorMessage;
    }
}
