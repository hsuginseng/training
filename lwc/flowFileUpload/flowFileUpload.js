import { LightningElement, api, track } from 'lwc';

export default class FileUploaderForFlow extends LightningElement {
    // Input property from the Flow
    @api label;

    // Output property that the Flow will read.
    // Must use @api to make it public.
    @api
    contentDocumentIds = [];

    // Internal property to display file names for good user experience
    @track
    uploadedFileNames = [];

    // This handler runs when the user finishes uploading files
    handleUploadFinished(event) {
        // Get the list of uploaded file objects
        const uploadedFiles = event.detail.files;

        // Extract just the documentId from each file
        const docIds = uploadedFiles.map(file => file.documentId);

        // Extract the names for display
        const fileNames = uploadedFiles.map(file => file.name);

        // Assign the extracted IDs to our public @api property.
        // The Flow will automatically pick this up when the user clicks 'Next'.
        this.contentDocumentIds = [...this.contentDocumentIds, ...docIds];

        // Update the list of names for display
        this.uploadedFileNames = [...this.uploadedFileNames, ...fileNames];
    }
}