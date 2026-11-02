const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.send('Hello, welcome to my app!');
});

app.get('/api', (req, res) => {
  res.json({ message: 'API endpoint is working!' });
});

app.listen(port, () => {
  console.log(`App is listening at http://localhost:${port}`);
});
