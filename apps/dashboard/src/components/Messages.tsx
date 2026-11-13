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

    // initial fetch + polling fallback
    const fetchMessages = () => {
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
          setConnectionStatus('error');
        });
    };

    fetchMessages();

    let ws: WebSocket | null = null;
    try {
      ws = new WebSocket(wsUrl);

      ws.onopen = () => {
        console.log('[dashboard] websocket connected');
        setConnectionStatus('connected');
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
        console.error('[dashboard] websocket error');
      };

      ws.onclose = () => {
        console.log('[dashboard] websocket closed');
      };
    } catch (err) {
      console.error('[dashboard] websocket init failed:', err);
    }

    const interval = setInterval(fetchMessages, 2000);

    return () => {
      if (ws) ws.close();
      clearInterval(interval);
    };
  }, []);

  return (
    <div>
      <div style={{ marginBottom: '1rem', fontSize: '0.9rem' }}>
        Status: <strong>{connectionStatus}</strong> — total {messages.length} messages
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
          {messages.map((m) => (
            <tr key={m.id}>
              <td>{String(m.seq).padStart(4, '0')}</td>
              <td>{formatDate(m.receivedAt)}</td>
              <td>{formatTime(m.receivedAt)}</td>
              <td>{m.topic}</td>
              <td>{m.qos}</td>
              <td>{m.latencyMs}ms</td>
              <td>{m.status}</td>
              <td>{m.payload}</td>
            </tr>
          ))}
        </tbody>
      </Table>
    </div>
  );
}

export default Messages;