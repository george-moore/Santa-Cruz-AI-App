import * as React from 'react';
import { Button, Modal, Form } from 'semantic-ui-react';
import { ErrorStore } from '../stores';
import { observer, inject } from 'mobx-react';
import { bind } from '../../utils';

interface IErrorDialogProps {
    errorStore?: ErrorStore;
}

@inject('errorStore') @observer
export class ErrorDialog extends React.Component<IErrorDialogProps, any> {
    public render() {
        const {
            errorStore
        } = this.props;

        return (
            <Modal size="mini" open={errorStore.shouldShow}>
                <Modal.Header>{errorStore.title}</Modal.Header>
                <Modal.Content>
                    <Form>
                        <Form.Field>
                            <label>{errorStore.message}</label>
                        </Form.Field>
                    </Form>
                </Modal.Content>
                <Modal.Actions>
                    <Button onClick={this.dismiss}>Close</Button>
                </Modal.Actions>
            </Modal>
        );
    }

    @bind
    private dismiss() {
        this.props.errorStore.shouldShow = false;
    }
}
