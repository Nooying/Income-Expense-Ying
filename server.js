const express = require('express');
const path = require('path');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.static(path.join(__dirname, 'public')));
app.use(express.static(path.join(__dirname)));

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'finance-app.html'));
});

app.get('/finance', (req, res) => {
  res.sendFile(path.join(__dirname, 'finance-app.html'));
});

app.listen(PORT, () => {
  console.log(`Finance App running on port ${PORT}`);
});
