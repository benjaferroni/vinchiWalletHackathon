const http = require('http');
const fs = require('fs');

const data = JSON.stringify({
    category: "entretenimiento",
    amount: 1000,
    dayOfWeek: 1 // Tuesday
});

const options = {
    hostname: 'localhost',
    port: 3001,
    path: '/api/route',
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data)
    }
};

const req = http.request(options, res => {
    let responseText = '';
    res.on('data', chunk => responseText += chunk);
    res.on('end', () => {
        fs.writeFileSync('out.json', responseText);
        console.log('Done');
    });
});

req.on('error', console.error);
req.write(data);
req.end();
