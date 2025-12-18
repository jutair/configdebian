# Cria a pasta .ssh no novo usuário
mkdir -p /home/jutair/.ssh

# Copia as chaves autorizadas do root para o usuário
cp /root/.ssh/authorized_keys /home/jutair/.ssh/

# Ajusta as permissões (MUITO IMPORTANTE)
# O SSH não funciona se as permissões estiverem abertas demais
chown -R jutair:jutair /home/jutair/.ssh
chmod 700 /home/jutair/.ssh
chmod 600 /home/jutair/.ssh/authorized_keys
