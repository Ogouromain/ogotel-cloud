'use client'

import { useEffect } from 'react'

export default function Home() {
  useEffect(() => {
    window.location.href = '/landing'
  }, [])

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      minHeight: '100vh',
      gap: '1.5rem',
      background: '#0D1F0F'
    }}>
      <div style={{
        fontSize: '2rem',
        marginBottom: '0.5rem'
      }}>🏨</div>
      <div style={{
        fontFamily: "'Playfair Display', Georgia, serif",
        fontSize: '1.8rem',
        fontWeight: 700,
        color: '#F9A825',
        letterSpacing: '-0.02em'
      }}>
        OGOTEL <span style={{ color: '#fff' }}>Cloud</span>
      </div>
      <div style={{
        fontSize: '0.95rem',
        color: 'rgba(255,255,255,0.6)',
        marginTop: '0.5rem'
      }}>Chargement en cours...</div>
      <div style={{
        marginTop: '1rem',
        width: '32px',
        height: '32px',
        border: '3px solid rgba(255,255,255,0.15)',
        borderTopColor: '#F9A825',
        borderRadius: '50%',
        animation: 'spin 0.8s linear infinite'
      }} />
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  )
}
