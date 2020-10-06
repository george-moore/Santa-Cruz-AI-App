import React from 'react';
import axios from 'axios';
import './App.css';
import { Pivot, PivotItem } from 'office-ui-fabric-react/lib/Pivot';
import io from 'socket.io-client';
import { Camera } from './components/Camera';
import { Password } from './components/Password';
import { RealTimeMetrics } from './components/RealTimeMetrics';
import { CountOfPeopleVsTime } from './components/CountOfPeopleVsTime';
import { AggregateStatsInTimeWindow } from './components/AggregateStatsInTimeWindow';
import { AggregateCountOfPeopleVsTime } from './components/AggregateCountOfPeopleVsTime';
import { Azure } from './components/Azure';
import { EditZones } from './components/EditZones';
import { Collision } from './models/Collision';
import { BlobImage } from './models/BlobImage';
import { initializeIcons } from 'office-ui-fabric-react/lib/Icons';

initializeIcons(/* optional base url */);

const collision = new Collision(false);
const blobImage = new BlobImage();

const { BlobServiceClient } = require("@azure/storage-blob");
const isAdmin = false;

let account = null;
let eventHub = null;
let containerName = null;
let blobPath = null;
let sharedAccessSignature = null;
let blobServiceClient = null;
let socket = null;
let socketUrl = null;

class App extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            width: 640,
            height: 360,
            fps: 30,
            aggregator: {
                lines: [],
                zones: [{
                    name: "queue",
                    polygon: [],
                    threshold: 10.0
                }]
            },
            selectedZoneIndex: 0,
            frame: {
                detections: []
            },
            frames: [],
            collisions: 0,
            detections: 0,
            image: new Image(),
            accessGranted: isAdmin,
            blobServiceClient: blobServiceClient,
            realTimeChart: true,
            aggregateChartMetrics: {
                times: [],
                collisions: [],
                detections: []
            }
        }
    }

    componentDidMount() {
        if(process.env.NODE_ENV === 'development') {
            this.setup({
                account: process.env.REACT_APP_account,
                eventHub: process.env.REACT_APP_eventHub,
                containerName: process.env.REACT_APP_containerName,
                blobPath: process.env.REACT_APP_blobPath,
                sharedAccessSignature: process.env.REACT_APP_sharedAccessSignature,
                socketUrl: process.env.REACT_APP_socketUrl
            });
        } else {
            axios.get(`./settings`)
                .then((response) => {
                    const data = response.data;
                    this.setup({
                        ...data,
                        socketUrl: window.location.host
                    });
                })
                .catch((e) => {
                    this.setup({
                        account: process.env.REACT_APP_account,
                        eventHub: process.env.REACT_APP_eventHub,
                        containerName: process.env.REACT_APP_containerName,
                        blobPath: process.env.REACT_APP_blobPath,
                        sharedAccessSignature: process.env.REACT_APP_sharedAccessSignature,
                        socketUrl: process.env.REACT_APP_socketUrl
                    });
                });
        }
    }

    render() {
        return this.state.accessGranted ? (
            <React.Fragment>
                <Azure />
                <div style={{
                    display: "flex",
                    flexDirection: "column",
                    justifyContent: "center",
                    alignItems: "center",
                    margin: 10,
                    padding: 10
                }}>
                    <div
                        style={{
                            display: 'flex',
                            flexDirection: 'row',
                            backgroundColor: 'white',
                            margin: 10,
                            padding: 10
                        }}
                    >
                        <div
                            style={{
                                display: 'flex',
                                flexDirection: 'column'
                            }}
                        >
                            {
                                this.isAdmin ? (
                                    <Pivot>
                                        <PivotItem
                                            headerText="Demo"
                                        />
                                        <PivotItem

                                            headerText="Live"
                                        />
                                    </Pivot>
                                ) : null
                            }
                            <Camera
                                fps={this.state.fps}
                                width={this.state.width}
                                height={this.state.height}
                                aggregator={this.state.aggregator}
                                selectedZoneIndex={this.state.selectedZoneIndex}
                                updateSelectedZoneIndex={this.updateSelectedZoneIndex}
                                frame={this.state.frame}
                                image={this.state.image}
                                updateAggregator={this.updateAggregator}
                                collision={collision}
                            />
                            <Pivot
                                onLinkClick={(item) => {
                                    this.setState({
                                        realTimeChart: item.props.itemKey === "realtime"
                                    });
                                }}
                            >
                                <PivotItem
                                    headerText="Real time"
                                    itemKey="realtime"
                                />
                                <PivotItem
                                    headerText="Aggregate"
                                    itemKey="aggregate"
                                />
                            </Pivot>
                            {
                                this.state.realTimeChart ?
                                    <CountOfPeopleVsTime
                                        aggregator={this.state.aggregator}
                                        frame={this.state.frame}
                                        collisions={this.state.collisions}
                                        detections={this.state.detections}
                                    /> :
                                    <AggregateCountOfPeopleVsTime
                                        aggregator={this.state.aggregator}
                                        frame={this.state.frame}
                                        collisions={this.state.collisions}
                                        detections={this.state.detections}
                                        aggregateChartMetrics={this.state.aggregateChartMetrics}
                                    />
                            }
                        </div>
                        <div
                            style={{
                                display: 'flex',
                                flexDirection: 'column',
                                backgroundColor: 'white',
                                margin: 10,
                                padding: 10
                            }}
                        >
                            <RealTimeMetrics
                                aggregator={this.state.aggregator}
                                frame={this.state.frame}
                                collisions={this.state.collisions}
                                detections={this.state.detections}
                            />
                            <AggregateStatsInTimeWindow
                                aggregator={this.state.aggregator}
                                isBBoxInZones={collision.isBBoxInZones}
                                eventHub={eventHub}
                                blobServiceClient={blobServiceClient}
                                updateAggregateChartMetrics={this.updateAggregateChartMetrics}
                            />
                            <EditZones
                                aggregator={this.state.aggregator}
                                selectedZoneIndex={this.state.selectedZoneIndex}
                                updateAggregator={this.updateAggregator}
                                updateSelectedZoneIndex={this.updateSelectedZoneIndex}
                            />
                        </div>
                    </div>
                </div>
            </React.Fragment>
        ) : (
                <React.Fragment>
                    <Azure />
                    <Password updatePassword={this.updatePassword} />
                </React.Fragment>
            );
    }

    setup(data) {
        // blob storage
        account = data.account;
        eventHub = data.eventHub;
        containerName = data.containerName;
        blobPath = data.blobPath;
        sharedAccessSignature = data.sharedAccessSignature;
        blobServiceClient = new BlobServiceClient(`https://${account}.blob.core.windows.net?${sharedAccessSignature}`);
        socketUrl = data.socketUrl;

        // messages
        socket = io(`wss://${socketUrl}`, { transports: ['websocket'] });

        socket.on('connect', function () {
            console.log('connected!');
        });
        socket.on('message', (message) => {
            const data = JSON.parse(message);
            this.updateData(data);
        });
        socket.on('passwordchecked', (message) => {
            const data = JSON.parse(message);
            if (data.success) {
                localStorage.setItem("UES-APP-PASSWORD", btoa(data.value));
                this.setState({
                    accessGranted: true
                });
            }
        });

        // password
        let password = "";
        const passwordEncoded = localStorage.getItem("UES-APP-PASSWORD") || "";
        if (passwordEncoded !== "") {
            const passwordDecoded = atob(passwordEncoded);
            this.checkPassword(passwordDecoded);
        } else {
            this.checkPassword("");
        }

        // aggregator
        let aggregator = this.state.aggregator;
        const aggregatorEncoded = localStorage.getItem("UES-APP-AGGREGATOR") || "";
        if (aggregatorEncoded !== "") {
            const aggregatorDecoded = atob(aggregatorEncoded);
            aggregator = JSON.parse(aggregatorDecoded);
            this.setState({
                aggregator: aggregator
            });
        }
    }

    updateAggregateChartMetrics = (metrics) => {
        this.setState({
            aggregateChartMetrics: metrics
        });
    }

    updateAggregator = (aggregator) => {
        localStorage.setItem("UES-APP-AGGREGATOR", btoa(JSON.stringify(aggregator)));
        this.setState({
            aggregator: aggregator
        });
    }

    updateSelectedZoneIndex = (index) => {
        this.setState({
            selectedZoneIndex: index
        });
    }

    updatePassword = (e) => {
        const value = e.target.value;
        this.checkPassword(value);
    }

    checkPassword = (value) => {
        socket.emit("checkpassword", value);
    }

    async updateData(data) {
        if (data && data.hasOwnProperty('body')) {
            const frame = data.body;
            if (frame.hasOwnProperty("cameraId")) {
                if (frame.hasOwnProperty('detections') && !this.state.rtcv) {
                    let collisions = 0;
                    let detections = 0;
                    const l = frame.detections.length;
                    for (let i = 0; i < l; i++) {
                        const detection = frame.detections[i];
                        if (detection.bbox) {
                            if (collision.isBBoxInZones(detection.bbox, this.state.aggregator.zones)) {
                                detection.collides = true;
                                collisions = collisions + 1;
                            } else {
                                detection.collides = false;
                            }
                        }
                        detections = detections + 1;
                    }
                    this.setState({
                        frame: frame,
                        collisions: collisions,
                        detections: detections
                    });
                }
                if (frame.hasOwnProperty("image_name")) {
                    const image = new Image();
                    image.src = await blobImage.updateImage(blobServiceClient, containerName, blobPath, frame.image_name);
                    this.setState({
                        image: image
                    });
                }
            }
        }
    }
}

export default App;
