import Messages from './components/Messages';
import './App.css';

function App() {
  return (
    <div className="app-container">
      <header className="app-header">
        <div className="logo-area">
          <span className="logo-icon">⚡</span>
          <h1>MQTT Telemetry Hub</h1>
        </div>
        <p className="subtitle">Real-time IoT Data Ingestion Pipeline</p>
      </header>

      <main className="main-content">
        <div className="dashboard-card">
          <Messages />
        </div>
      </main>

      <footer className="app-footer">
        <p>Powered by React & MQTT.js | Monorepo Architecture</p>
      </footer>
    </div>
  );
}

export default App;