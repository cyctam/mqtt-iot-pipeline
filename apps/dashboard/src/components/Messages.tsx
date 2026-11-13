import { useState, useEffect } from 'react';
import { Table } from 'react-bootstrap';
import './Messages.css';

interface IMessage {
  id: string;
  seq: number;
  topic: string;
  payload: string;
  qos: number;
  latencyMs: number;
  status: string;
  receivedAt: string;
}

const formatDate = (iso: string): string => {
  const d = new Date(iso);
  return d.toLocaleDateString('id-ID');
};

const formatTime = (iso: string): string => {
  const d = new Date(iso);
  return d.toLocaleTimeString();
};

function Messages() {
  const [messages, setMessages] = useState<IMessage[]>([]);
  const [connectionStatus, setConnectionStatus] = useState<string>('connecting');

  useEffect(() => {
    const apiUrl = import.meta.env.VITE_API_URL || 'http://localhost:4000/api';
    const wsUrl = import.meta.env.VITE_WS_URL || 'ws://localhost:4000/ws';
    let isMockMode = false;
    let mockInterval: NodeJS.Timeout;
    let seqCounter = 1;

    const startMockSimulation = () => {
      if (isMockMode) return;
      isMockMode = true;
      setConnectionStatus('simulated (demo)');
      
      mockInterval = setInterval(() => {
        const newMock: IMessage = {
          id: Date.now().toString(),
          seq: seqCounter++,
          topic: 'iot/telemetry/sensor-' + Math.floor(Math.random() * 10),
          payload: JSON.stringify({ temp: (Math.random() * 10 + 20).toFixed(1), hum: (Math.random() * 20 + 40).toFixed(1) }),
          qos: Math.floor(Math.random() * 2),
          latencyMs: Math.floor(Math.random() * 50) + 10,
          status: 'RECEIVED',
          receivedAt: new Date().toISOString(),
        };
        setMessages((prev) => [newMock, ...prev].slice(0, 20));
      }, 2000);
    };

    const fetchMessages = () => {
      if (isMockMode) return;
      
      fetch(`${apiUrl}/messages`)
        .then((r) => r.json())
        .then((res) => {
          if (res.success) {
            setMessages(res.data);
            setConnectionStatus('connected');
          }
        })
        .catch((err) => {
          console.error('[dashboard] fetch failed:', err);
          if (!isMockMode) {
            startMockSimulation();
          }
        });
    };

    fetchMessages();

    let ws: WebSocket | null = null;
    try {
      ws = new WebSocket(wsUrl);

      ws.onopen = () => {
        if (!isMockMode) setConnectionStatus('connected');
      };

      ws.onmessage = (event) => {
        try {
          const msg = JSON.parse(event.data);
          if (msg.type === 'init' && Array.isArray(msg.data)) {
            setMessages(msg.data);
          }
        } catch {
        }
      };

      ws.onerror = () => {
        console.error('[dashboard] websocket error, falling back to mock');
        if (!isMockMode) startMockSimulation();
      };

      ws.onclose = () => {
        if (!isMockMode) startMockSimulation();
      };
    } catch (err) {
      console.error('[dashboard] websocket init failed:', err);
      startMockSimulation();
    }

    const interval = setInterval(fetchMessages, 3000);

    return () => {
      if (ws) ws.close();
      clearInterval(interval);
      if (mockInterval) clearInterval(mockInterval);
    };
  }, []);

  return (
    <div>
      <div style={{ marginBottom: '1rem', fontSize: '0.9rem', display: 'flex', justifyContent: 'space-between' }}>
        <span>Status: <strong>{connectionStatus}</strong> — total {messages.length} messages</span>
        {connectionStatus.includes('simulated') && (
          <span style={{ color: '#f59e0b', fontSize: '0.8rem' }}>Demo Mode: Displaying simulated data</span>
        )}
      </div>
      <Table striped borderless hover responsive variant="dark">
        <thead>
          <tr>
            <th>Seq</th>
            <th>Date</th>
            <th>Time</th>
            <th>Topic</th>
            <th>QoS</th>
            <th>Latency</th>
            <th>Status</th>
            <th>Payload</th>
          </tr>
        </thead>
        <tbody>
          {messages.length === 0 ? (
            <tr>
              <td colSpan={8} style={{ textAlign: 'center', padding: '2rem' }}>
                Waiting for incoming telemetry data...
              </td>
            </tr>
          ) : (
            messages.map((m) => (
              <tr key={m.id}>
                <td>{String(m.seq).padStart(4, '0')}</td>
                <td>{formatDate(m.receivedAt)}</td>
                <td>{formatTime(m.receivedAt)}</td>
                <td>{m.topic}</td>
                <td>{m.qos}</td>
                <td>{m.latencyMs}ms</td>
                <td>{m.status}</td>
                <td style={{ maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{m.payload}</td>
              </tr>
            ))
          )}
        </tbody>
      </Table>
    </div>
  );
}

export default Messages;