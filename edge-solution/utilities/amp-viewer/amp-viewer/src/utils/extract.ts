export function extract<T>(properties: Record<keyof T, true>) {
    return <TActual extends T>(value: TActual) => {
        // tslint:disable-next-line: no-object-literal-type-assertion
        const result = {} as T;

        for (const property of Object.keys(properties) as Array<keyof T>) {
            result[property] = value[property];
        }

        return result;
    };
}
