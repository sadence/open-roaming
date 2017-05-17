'use strict'

const express = require('express');
const forge = require('node-forge');
const fileUpload = require('express-fileupload');
const params = require('./config.json');
const https = require('https');
const fs = require('fs');

const app = express()

const CACertPem = fs.readFileSync(params.CACert, 'utf8');
const CAKeyPem = fs.readFileSync(params.CAKey, 'utf8');

const CACert = forge.pki.certificateFromPem(CACertPem);
const CAKey = forge.pki.decryptRsaPrivateKey(CAKeyPem, params.KeyPassword);
let serial = parseInt(params.BeginningSerial);

app.use(fileUpload())
.post('/signCertificat', (req, res) => {
    if(!req.files)
        res.sendStatus(404);
    else {
        try {
            let csr = forge.pki.certificationRequestFromPem(req.files.csr.data);
            
            if(csr.verify()) {
                console.log('Certification request (CSR) verified.');
            } else {
                throw new Error('Signature not verified.');
            }

            let cert = forge.pki.createCertificate();
            cert.serialNumber = String(serial);
            cert.validity.notBefore = new Date();
            cert.validity.notAfter = new Date();
            cert.validity.notAfter.setFullYear(cert.validity.notBefore.getFullYear() + 1);
            cert.setSubject(csr.subject.attributes);
            cert.setIssuer(CACert.subject.attributes);
            cert.setExtensions([{
                name: 'basicConstraints',
                cA: true,
                critical: true,
                pathLenConstraint: '0'
            }, {
                name: 'keyUsage',
                critical: true,
                digitalSignature: true,
                cRLSign: true,
                keyCertSign: true
            }]);
            cert.publicKey = csr.publicKey;
            cert.sign(CAKey);
            let PemCert = forge.pki.certificateToPem(cert);
            let fileName = __dirname+'/certificat/'+serial+'.cert.pem';
            fs.writeFileSync(fileName, PemCert);
            res.download(fileName);
            serial++;
        } catch (error) {
            res.sendStatus(500);
        }
    }
})
.get('/rootCA', (req, res) => {
    res.download(params.CACert);
})

const option = {
    key: fs.readFileSync(params.ServerKey),
    cert: fs.readFileSync(params.ServerCert)
}

let server = https.createServer(option, app).listen(443, () => {
    console.log('Server start on port 443');
})
