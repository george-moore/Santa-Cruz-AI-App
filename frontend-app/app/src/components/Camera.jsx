import React from 'react';
import { Editor } from './Editor';

export class Camera extends React.Component {
    static defaultProps = {
        border: '0px solid black',
        width: 300,
        height: 300,
        fps: 30,
        aggregator: {
            lines: [],
            zones: []
        },
        frame: {
            detections: []
        },
        image: new Image()
    }
    constructor(props) {
        super(props);
        this.state = {
            aggregator: JSON.parse(JSON.stringify(this.props.aggregator)),
        };

        this.canvasRef = React.createRef();
    }

    componentDidMount() {
        setInterval(() => {
            this.draw();
        }, 1000 / this.props.fps);
    }

    componentDidUpdate(prevProps) {
        if (prevProps.aggregator !== this.props.aggregator) {
            this.setState({
                aggregator: this.props.aggregator
            })
        }
    }

    render() {
        return (
            <React.Fragment>
                <div
                    style={{
                        margin: 10,
                        width: this.props.width,
                        height: this.props.height,
                        position: 'relative'
                    }}
                >
                    <canvas
                        ref={this.canvasRef}
                        width={this.props.width}
                        height={this.props.height}
                        style={{
                            border: this.props.border,
                            position: 'absolute',
                            zIndex: 0
                        }}
                        tabIndex={1}
                    />
                    <Editor
                        fps={this.props.fps}
                        width={this.props.width}
                        height={this.props.height}
                        aggregator={this.props.aggregator}
                        updateAggregator={this.props.updateAggregator}
                        selectedZoneIndex={this.props.selectedZoneIndex}
                        updateSelectedZoneIndex={this.props.updateSelectedZoneIndex}
                        collision={this.props.collision}
                    />
                </div>
            </React.Fragment>
        );
    }

    clamp = (value, min, max) => {
        return Math.min(Math.max(value, min), max);
    }

    draw = () => {
        const canvasContext = this.canvasRef.current?.getContext("2d");
        if (canvasContext) {
            canvasContext.clearRect(0, 0, this.props.width, this.props.height);
            canvasContext.drawImage(this.props.image, 0, 0, this.props.width, this.props.height);
            this.drawDetections(canvasContext, this.props.frame.detections);
        }
    }

    drawDetections(canvasContext, detections) {
        const l = detections.length;
        for (let i = 0; i < l; i++) {
            const detection = detections[i];
            this.drawDetection(canvasContext, detection);
        }
    }

    drawDetection(canvasContext, detection) {
        if (detection.bbox) {
            if (detection.collides) {
                canvasContext.strokeStyle = 'yellow';
                canvasContext.lineWidth = 4;
            } else {
                canvasContext.strokeStyle = 'lightblue';
                canvasContext.lineWidth = 2;
            }
            const x = this.props.width * detection.bbox[0];
            const y = this.props.height * detection.bbox[1];
            const w = this.props.width * Math.abs(detection.bbox[2] - detection.bbox[0]);
            const h = this.props.height * Math.abs(detection.bbox[3] - detection.bbox[1]);
            canvasContext.strokeRect(x, y, w, h);
        } else if (detection.rectangle) {
            canvasContext.strokeStyle = 'yellow';
            canvasContext.lineWidth = 2;
            const x = this.props.width * detection.rectangle.left;
            const y = this.props.height * detection.rectangle.top;
            const w = this.props.width * detection.rectangle.width;
            const h = this.props.height * detection.rectangle.height;
            canvasContext.strokeRect(x, y, w, h);
        }
    }
}
