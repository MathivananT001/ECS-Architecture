const express = require('express');
const app = express();

const PORT = process.env.PORT || 8080;
const HOSTNAME = '0.0.0.0';

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

// Main endpoint
app.get('/', (req, res) => {
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <title>Serverless ECS App</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          display: flex;
          justify-content: center;
          align-items: center;
          height: 100vh;
          margin: 0;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .container {
          text-align: center;
          background: white;
          padding: 40px;
          border-radius: 10px;
          box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
        }
        h1 {
          color: #333;
          margin: 0 0 20px 0;
        }
        p {
          color: #666;
          font-size: 16px;
          margin: 10px 0;
        }
        .info {
          background: #f5f5f5;
          padding: 15px;
          border-radius: 5px;
          margin-top: 20px;
          text-align: left;
          font-family: monospace;
          font-size: 14px;
        }
        .success {
          color: #28a745;
          font-weight: bold;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>👋 Hello World</h1>
        <p class="success">Your serverless application is running!</p>
        <p>This is a simple Node.js Express application running on ECS Fargate</p>
        <div class="info">
          <p><strong>Service:</strong> Serverless App</p>
          <p><strong>Platform:</strong> AWS ECS Fargate</p>
          <p><strong>Port:</strong> ${PORT}</p>
          <p><strong>Time:</strong> ${new Date().toLocaleString()}</p>
          <p><strong>Hostname:</strong> ${require('os').hostname()}</p>
        </div>
      </div>
    </body>
    </html>
  `;
  res.send(html);
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, HOSTNAME, () => {
  console.log(`🚀 Server running at http://${HOSTNAME}:${PORT}`);
  console.log(`📊 Health check at http://${HOSTNAME}:${PORT}/health`);
});
