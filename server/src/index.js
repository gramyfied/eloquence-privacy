import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import path from 'path';
import winston from 'winston';

// Routes
import speechRoutes from './api/speech.js';
import ttsRoutes from './api/tts.js';
import pronunciationRoutes from './api/pronunciation.js';
import aiRoutes from './api/ai.js';
import testRoutes from './api/test.js';

// Middleware
import { errorHandler } from './middleware/errorHandler.js';
import { apiKeyAuth } from './middleware/auth.js';

// Configuration
dotenv.config();
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    }),
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' })
  ]
});

// App
const app = express();
const port = process.env.PORT || 3000;

// CORS configuration
const corsOptions = {
  origin: process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',') : '*',
  methods: ['GET', 'POST'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  maxAge: 86400 // 24 heures
};

// Middleware
app.use(cors(corsOptions));
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// Logging middleware
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.url}`);
  next();
});

// Routes
app.get('/', (req, res) => {
  res.json({
    message: 'Bienvenue sur l\'API Eloquence',
    version: '1.0.0',
    endpoints: [
      '/api/speech/recognize',
      '/api/tts/synthesize',
      '/api/pronunciation/evaluate',
      '/api/ai/feedback',
      '/api/ai/chat'
    ]
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// API routes with authentication
app.use('/api/speech', apiKeyAuth, speechRoutes);
app.use('/api/tts', apiKeyAuth, ttsRoutes);
app.use('/api/pronunciation', apiKeyAuth, pronunciationRoutes);
app.use('/api/ai', apiKeyAuth, aiRoutes);

// Test route (pas d'auth pour faciliter les tests)
app.use('/api/test', testRoutes);

// Error handler
app.use(errorHandler);

// Start server
app.listen(port, () => {
  logger.info(`Serveur démarré sur le port ${port}`);
  logger.info(`Mode: ${process.env.NODE_ENV}`);
});

export default app;
