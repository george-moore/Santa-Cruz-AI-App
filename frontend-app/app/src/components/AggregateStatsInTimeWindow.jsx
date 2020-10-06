import React from 'react';
import { DefaultButton } from '@fluentui/react/lib/Button';
import { Label } from 'office-ui-fabric-react/lib/Label';
import { Text } from 'office-ui-fabric-react/lib/Text';
import { TextField } from 'office-ui-fabric-react/lib/TextField';

export class AggregateStatsInTimeWindow extends React.Component {
    static defaultProps = {
        aggregator: {
            lines: [],
            zones: [{
                name: "queue",
                polygon: [],
                threshold: 10.0
            }]
        },
    }

    constructor(props) {
        super(props);
        this.state = {
            totalCollisions: 0,
            totalDetections: 0,
            maxCollisionsPerSecond: 0,
            maxDetectionsPerSecond: 0,
            calculating: false,
            startDate: "",
            startTime: "",
            endDate: "",
            endTime: ""
        }
        this.startDateTimeRef = React.createRef();
        this.endDateTimeRef = React.createRef();
    }


    render() {
        const names = this.props.aggregator.zones.map((zone, index) => {
            return (
                <span key={index}>{index > 0 ? ',' : null}{zone.name}</span>
            )
        });
        return (
            <React.Fragment>
                <div
                    style={{
                        margin: 10
                    }}
                >
                    <div>
                        <Label style={{fontWeight: 'bold'}}>Aggregate stats in time window</Label>
                    </div>
                    <div
                        style={{
                            margin: 5
                        }}
                    >
                        <table width="100%">
                            <tbody>
                                <tr>
                                    <td colSpan={3}>
                                        <input
                                            ref={this.endDateTimeRef}
                                            type="datetime-local"
                                            style={{
                                                width: '100%',
                                                marginBottom: 10
                                            }}
                                            onChange={(e) => {
                                                const endDateTime = new Date(e.target.value);
                                                const startDateTime = new Date(e.target.value);
                                                let minutes = startDateTime.getMinutes();
                                                minutes = minutes - 15;
                                                startDateTime.setMinutes(minutes);
                                                this.setState({
                                                    startDate: this.formatDate(startDateTime),
                                                    startTime: this.formatTime(startDateTime),
                                                    endDate: this.formatDate(endDateTime),
                                                    endTime: this.formatTime(endDateTime)
                                                });
                                            }}
                                        />
                                    </td>
                                </tr>
                                <tr>
                                    <td>
                                        <Label>Start</Label>
                                    </td>
                                    <td>
                                        <TextField
                                            readOnly
                                            value={this.state.startDate}
                                        />
                                    </td>
                                    <td>
                                        <TextField
                                            readOnly
                                            value={this.state.startTime}
                                        />
                                    </td>
                                </tr>
                                <tr>
                                    <td>
                                        <Label>End</Label>
                                    </td>
                                    <td>
                                        <TextField
                                            readOnly
                                            value={this.state.endDate}
                                        />
                                    </td>
                                    <td>
                                        <TextField
                                            readOnly
                                            value={this.state.endTime}
                                        />
                                    </td>
                                </tr>
                                <tr>
                                    <td colSpan={3} align="right">
                                        <DefaultButton
                                            style={{
                                                marginTop: 10
                                            }}
                                            disabled={this.endDateTimeRef.current === null || this.endDateTimeRef.current.value === "" || new Date(this.endDateTimeRef.current.value) >= new Date() || new Date(this.endDateTimeRef.current.value) < new Date(2020, 5, 27)}
                                            onClick={(e) => {
                                                this.setState({
                                                    calculating: true
                                                }, () => {
                                                    this.calculate();
                                                });
                                            }}
                                        >
                                            Calculate
                                        </DefaultButton>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                    {
                        this.state.calculating ? <div>Calculating... </div> : (
                            <React.Fragment>
                                <Text variant={'medium'} block>
                                    Max people detections in frame per second
                                </Text>
                                <Text variant={'medium'} block>
                                    <b>{this.state.maxDetectionsPerSecond}</b>
                                </Text>
                                <Text variant={'medium'} block>
                                    Max people detections in zones ({names}) per second
                                </Text>
                                <Text variant={'medium'} block>
                                    <b>{this.state.maxCollisionsPerSecond}</b>
                                </Text>
                            </React.Fragment>
                        )
                    }
                </div>
            </React.Fragment>
        );
    }

    parseEventHub = (eventHub) => {
        return eventHub.split('=')[1].split('.')[0];
    }

    async calculate() {
        // for chart
        const metrics = {
            times: [],
            collisions: [],
            detections: []
        }

        // parse the start datetime to get a list of all the blobs
        const startDateTime = new Date(this.endDateTimeRef.current.value);
        const endDateTime = new Date(startDateTime);
        startDateTime.setMinutes(startDateTime.getMinutes() - 15);

        const containerNames = [];
        while (startDateTime < endDateTime) {
            containerNames.push({
                hour: `${startDateTime.toLocaleDateString('fr-CA', {
                    year: 'numeric',
                    month: '2-digit',
                    day: '2-digit'
                }).replace(/-/g, '/')}/${startDateTime.toLocaleTimeString([], { hour: '2-digit' }).split(' ')[0]}`,
                minute: `${startDateTime.toLocaleDateString('fr-CA', {
                    year: 'numeric',
                    month: '2-digit',
                    day: '2-digit'
                }).replace(/-/g, '/')}/${startDateTime.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }).replace(/:/g, '/').split(' ')[0]}`
            });

            startDateTime.setMinutes(startDateTime.getMinutes() + 1);
        }

        const parsedEventHub = this.parseEventHub(this.props.eventHub);

        // calculate the frames for all of the blobs
        let frames = [];
        const cl = containerNames.length;
        for (let i = 0; i < cl; i++) {
            const containerNameHour = `${parsedEventHub}/00/${containerNames[i].hour}`;
            const containerNameMinute = `${parsedEventHub}/00/${containerNames[i].minute}`;
            const exists = await this.blobExists("detectoroutput", containerNameHour);
            if (exists) {
                const containerClient = this.props.blobServiceClient.getContainerClient("detectoroutput");
                let iter = containerClient.listBlobsByHierarchy("/", { prefix: containerNameMinute });
                // console.log(containerNameMinute);
                const blobs = [];
                for await (const item of iter) {
                    const blob = await this.downloadBlob("detectoroutput", item.name);
                    blobs.push(blob);
                }

                frames = [...frames, ...this.calculateFrames(blobs)];
            }
        }

        // calculate the max per second and total max per second metrics
        let totalCollisions = 0;
        let maxCollisions = 0;
        let totalDetections = 0;
        let maxDetections = 0;

        const fl = frames.length;
        for (let i = 0; i < fl; i++) {
            const frame = frames[i];
            totalCollisions = totalCollisions + frame.maxCollisions;
            totalDetections = totalDetections + frame.maxDetections;
            if (maxCollisions < frame.maxCollisions) {
                maxCollisions = frame.maxCollisions;
            }
            if (maxDetections < frame.maxDetections) {
                maxDetections = frame.maxDetections;
            }
            metrics.times.push(frame.time);
            metrics.collisions.push(frame.maxCollisions);
            metrics.detections.push(frame.maxDetections);
        }

        this.setState({
            totalCollisions: totalCollisions,
            maxCollisionsPerSecond: maxCollisions,
            totalDetections: totalDetections,
            maxDetectionsPerSecond: maxDetections,
            calculating: false
        }, () => {
            this.props.updateAggregateChartMetrics(metrics);
        });
    }

    calculateFrames = (blobs) => {
        const frames = [];
        let time = null;
        let frame = {
            detections: [],
            maxDetections: 0,
            maxCollisions: 0,
            time: ""
        }
        for (const blob of blobs) {
            const l = blob.length;
            for (let i = 0; i < l; i++) {
                const item = blob[i];
                const t = new Date(item.image_name).getTime();
                const maxCollisions = this.calculateCollisions(item.detections);
                if (time === null) {
                    time = t;
                    frame.detections = item.detections;
                    frame.maxDetections = item.detections.length;
                    frame.maxCollisions = maxCollisions;
                    frame.time = t;
                    if (i + 1 === l) {
                        frames.push(frame);
                    }
                } else if (Math.abs(t - time) >= 1000) {
                    frames.push(frame);
                    time = t;
                    frame = {
                        detections: item.detections,
                        maxDetections: item.detections.length,
                        maxCollisions: maxCollisions,
                        time: t
                    }
                    if (i + 1 === l) {
                        frames.push(frame);
                    }
                } else {
                    frame.detections = [...frame.detections, ...item.detections];
                    frame.maxDetections = item.detections.length > frame.maxDetections ? item.detections.length : frame.maxDetections;
                    frame.maxCollisions = maxCollisions > frame.maxCollisions ? maxCollisions : frame.maxCollisions;
                    frame.time = t;
                    if (i + 1 === l) {
                        frames.push(frame);
                    }
                }
            }
        }
        return frames;
    }

    calculateCollisions = (detections) => {
        let collisions = 0;
        const l = detections.length;
        for (let i = 0; i < l; i++) {
            const detection = detections[i];
            if (detection.bbox) {
                if (this.props.isBBoxInZones(detection.bbox, this.props.aggregator.zones)) {
                    collisions = collisions + 1;
                }
            }
        }
        return collisions;
    }

    formatDate = (date) => {
        // Note: en-EN won't return in year-month-day order
        return date.toLocaleDateString('fr-CA', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        });
    }

    calculateNow = () => {
        const dt = new Date();
        return dt.toUTCString();
    }

    calculate15MinutesAhead = () => {
        const dt = new Date();
        dt.setMinutes(dt.minutes + 15);
        return dt;
    }

    formatTime = (date) => {
        // Note: en-EN won't return in without the AM/PM
        return date.toLocaleTimeString('it-IT');
    }

    async blobExists(containerName, blobName) {
        const containerClient = this.props.blobServiceClient.getContainerClient(containerName);
        const blobClient = containerClient.getBlobClient(blobName);
        const exists = blobClient.exists();
        return exists;
    }

    async downloadBlob(containerName, blobName) {
        const containerClient = this.props.blobServiceClient.getContainerClient(containerName);
        const blobClient = containerClient.getBlobClient(blobName);
        const downloadBlockBlobResponse = await blobClient.download();

        const downloaded = await this.blobToString(await downloadBlockBlobResponse.blobBody);
        const views = downloaded.replace(/\\"/g, /'/).split('\r\n');

        const frames = [];
        const l = views.length;
        for (let i = 0; i < l; i++) {
            const view = views[i];
            if (view && view !== undefined && view !== "") {
                let parsedView = JSON.parse(view);
                let body = parsedView.Body;
                let decodedBody = atob(body);
                let parsedBody = JSON.parse(decodedBody);
                frames.push(parsedBody);
            }
        }

        return frames;
    }

    async blobToString(blob) {
        const fileReader = new FileReader();
        return new Promise((resolve, reject) => {
            fileReader.onloadend = (ev) => {
                resolve(ev.target.result);
            };
            fileReader.onerror = reject;
            fileReader.readAsText(blob);
        });
    }
}