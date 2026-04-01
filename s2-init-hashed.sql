-- ============================================================================
-- LOGISTOCK S2 — Initialisation BDD avec HACHAGE des mots de passe
-- ============================================================================
-- Évolution de S1 : Les mots de passe sont maintenant HASHÉS avec SHA-256
-- ============================================================================

USE logistock;

-- ==========================================================================
-- Table users — Comptes avec mots de passe HASHÉS
-- ==========================================================================
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  password_hash CHAR(64) NOT NULL,  -- ✅ SHA-256 = 64 caractères hexadécimaux
  email VARCHAR(100) NOT NULL,
  role ENUM('admin', 'employee', 'manager') DEFAULT 'employee',
  mfa_enabled BOOLEAN DEFAULT FALSE,  -- ✅ Préparation MFA (S2)
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login TIMESTAMP NULL,
  failed_login_attempts INT DEFAULT 0,  -- ✅ Protection brute force
  account_locked BOOLEAN DEFAULT FALSE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ✅ Insertion avec hashs SHA-256
-- Note : En production, utiliser bcrypt/Argon2 avec sel, pas SHA-256 simple
INSERT INTO users (username, password_hash, email, role, mfa_enabled) VALUES
-- alice: LogiStock2024! → hash SHA-256
('alice', SHA2('LogiStock2024!', 256), 'alice@logistock.fr', 'employee', FALSE),

-- bob: AzertySecure!456 → hash SHA-256
('bob', SHA2('AzertySecure!456', 256), 'bob@logistock.fr', 'employee', FALSE),

-- daf: PdgSecure!789 → hash SHA-256
('daf', SHA2('PdgSecure!789', 256), 'daf@logistock.fr', 'manager', TRUE),

-- admin: AdminSecure!2024 → hash SHA-256
('admin', SHA2('AdminSecure!2024', 256), 'admin@logistock.fr', 'admin', TRUE),

-- charlie: CharliePwd!987 → hash SHA-256
('charlie', SHA2('CharliePwd!987', 256), 'charlie@logistock.fr', 'employee', FALSE);

-- ==========================================================================
-- Table documents — Fichiers avec historique de chiffrement
-- ==========================================================================
CREATE TABLE IF NOT EXISTS documents (
  id INT AUTO_INCREMENT PRIMARY KEY,
  filename VARCHAR(255) NOT NULL,
  category ENUM('rh', 'finance', 'logistique') NOT NULL,
  confidential BOOLEAN DEFAULT FALSE,
  encrypted BOOLEAN DEFAULT FALSE,  -- ✅ Nouveau : indicateur de chiffrement
  encryption_algorithm VARCHAR(50),  -- Ex: AES-256-CBC
  uploaded_by INT,
  upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_accessed TIMESTAMP NULL,
  FOREIGN KEY (uploaded_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Fichiers RH maintenant chiffrés
INSERT INTO documents (filename, category, confidential, encrypted, encryption_algorithm, uploaded_by) VALUES
('fiches_paie_2024.xlsx.enc', 'rh', TRUE, TRUE, 'AES-256-CBC', 3),
('contrats_employes.pdf.enc', 'rh', TRUE, TRUE, 'AES-256-CBC', 3),
('bilan_financier_2024.xlsx.enc', 'finance', TRUE, TRUE, 'AES-256-CBC', 3),
('inventaire_entrepot.csv', 'logistique', FALSE, FALSE, NULL, 2);

-- ==========================================================================
-- Table logs_acces — Journalisation AMÉLIORÉE
-- ==========================================================================
CREATE TABLE IF NOT EXISTS logs_acces (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT,
  action VARCHAR(100),
  ip_address VARCHAR(45),
  user_agent TEXT,  -- ✅ Nouveau : détection des outils automatisés
  success BOOLEAN,  -- ✅ Nouveau : succès ou échec
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id),
  INDEX idx_timestamp (timestamp),
  INDEX idx_user_action (user_id, action)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Logs avec plus de détails
INSERT INTO logs_acces (user_id, action, ip_address, user_agent, success) VALUES
(1, 'login', '192.168.1.50', 'Mozilla/5.0', TRUE),
(2, 'login', '192.168.1.51', 'Mozilla/5.0', TRUE),
(3, 'access_file_rh', '192.168.1.52', 'Mozilla/5.0', TRUE),
(NULL, 'failed_login', '203.0.113.42', 'curl/7.68.0', FALSE),  -- ✅ Tentative suspecte
(NULL, 'failed_login', '203.0.113.42', 'curl/7.68.0', FALSE);  -- ✅ Brute force détecté

-- ==========================================================================
-- Table crypto_keys — Gestion des clés de chiffrement (S2)
-- ==========================================================================
CREATE TABLE IF NOT EXISTS crypto_keys (
  id INT AUTO_INCREMENT PRIMARY KEY,
  key_name VARCHAR(100) NOT NULL UNIQUE,
  key_type ENUM('symmetric', 'asymmetric') NOT NULL,
  algorithm VARCHAR(50) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  rotated_at TIMESTAMP NULL,
  status ENUM('active', 'rotated', 'revoked') DEFAULT 'active'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Clés utilisées pour chiffrer les données
INSERT INTO crypto_keys (key_name, key_type, algorithm, status) VALUES
('rh_master_key', 'symmetric', 'AES-256-CBC', 'active'),
('tls_server_key', 'asymmetric', 'RSA-2048', 'active');

-- ==========================================================================
-- Vue pour audit de sécurité
-- ==========================================================================
CREATE VIEW security_audit AS
SELECT 
  u.username,
  u.role,
  u.mfa_enabled,
  u.failed_login_attempts,
  u.account_locked,
  COUNT(l.id) as total_accesses,
  MAX(l.timestamp) as last_activity
FROM users u
LEFT JOIN logs_acces l ON u.id = l.user_id
GROUP BY u.id;

-- ==========================================================================
-- Procédure stockée : Vérification de mot de passe (S2)
-- ==========================================================================
DELIMITER //
CREATE PROCEDURE check_password(
  IN p_username VARCHAR(50),
  IN p_password VARCHAR(255),
  OUT p_result BOOLEAN
)
BEGIN
  DECLARE v_hash CHAR(64);
  
  -- Calculer le hash du mot de passe fourni
  SET v_hash = SHA2(p_password, 256);
  
  -- Vérifier si le hash correspond
  SELECT EXISTS(
    SELECT 1 FROM users 
    WHERE username = p_username 
    AND password_hash = v_hash
    AND account_locked = FALSE
  ) INTO p_result;
  
  -- Logger la tentative
  IF p_result THEN
    INSERT INTO logs_acces (user_id, action, ip_address, success)
    SELECT id, 'login_success', '0.0.0.0', TRUE
    FROM users WHERE username = p_username;
    
    -- Réinitialiser les tentatives échouées
    UPDATE users 
    SET failed_login_attempts = 0, last_login = NOW()
    WHERE username = p_username;
  ELSE
    INSERT INTO logs_acces (user_id, action, ip_address, success)
    VALUES (NULL, 'login_failed', '0.0.0.0', FALSE);
    
    -- Incrémenter les tentatives échouées
    UPDATE users 
    SET failed_login_attempts = failed_login_attempts + 1
    WHERE username = p_username;
    
    -- Verrouiller le compte après 5 tentatives
    UPDATE users 
    SET account_locked = TRUE
    WHERE username = p_username AND failed_login_attempts >= 5;
  END IF;
END //
DELIMITER ;

-- ==========================================================================
-- Informations de diagnostic
-- ==========================================================================
SELECT 'Base de données LogiStock S2 initialisée' AS Status;
SELECT '✅ Mots de passe hashés avec SHA-256' AS Security;
SELECT CONCAT('Nombre d\'utilisateurs avec MFA : ', 
  SUM(CASE WHEN mfa_enabled THEN 1 ELSE 0 END)) AS MFA_Stats 
FROM users;

-- Test de la procédure de vérification
CALL check_password('alice', 'LogiStock2024!', @result);
SELECT @result AS 'Test login alice (devrait être 1=TRUE)';
