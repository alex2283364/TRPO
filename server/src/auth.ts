interface LoginResponse {
    authenticated: boolean;
    role_bound: boolean;
    token?: string;
}

interface BindRoleResponse {
    success: boolean;
    error?: string;
}

document.addEventListener('DOMContentLoaded', () => {
    const loginForm = document.getElementById('loginForm') as HTMLFormElement;
    const loginContainer = document.getElementById('loginContainer') as HTMLDivElement;
    const bindContainer = document.getElementById('bindRoleContainer') as HTMLDivElement;
    const bindForm = document.getElementById('bindRoleForm') as HTMLFormElement;
    const bindMessageDiv = document.getElementById('bindMessage') as HTMLDivElement;
    const backToLogin = document.getElementById('backToLogin') as HTMLAnchorElement;
    const messageDiv = document.getElementById('message') as HTMLDivElement;

    let currentLogin = ''; // сохраняем логин для привязки

    // Обработка формы входа
    loginForm.addEventListener('submit', async (e) => {
        e.preventDefault();

        const login = (document.getElementById('login') as HTMLInputElement).value.trim();
        const password = (document.getElementById('password') as HTMLInputElement).value;

        messageDiv.innerHTML = '';
        messageDiv.className = '';

        if (!login || !password) {
            showMessage('Пожалуйста, заполните все поля', 'error', messageDiv);
            return;
        }

        try {
            const response = await fetch('/login', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ login, password })
            });

            const result: LoginResponse = await response.json();

             if (result.authenticated) {
                if (result.role_bound) {
                    localStorage.setItem('username', login);
                    showMessage('Успешный вход! Перенаправление...', 'success', messageDiv);
                    setTimeout(() => window.location.href = '/user-info.html', 500);
                } else {
                    currentLogin = login;
                    loginContainer.style.display = 'none';
                    bindContainer.style.display = 'block';
                }
            } else {
                showMessage('Неверный логин или пароль', 'error', messageDiv);
            }
        } catch (error) {
            console.error('Ошибка:', error);
            showMessage('Ошибка сети или сервера', 'error', messageDiv);
        }
    });

    // Обработка привязки роли
    bindForm.addEventListener('submit', async (e) => {
        e.preventDefault();

        const rolePassword = (document.getElementById('rolePassword') as HTMLInputElement).value.trim();

        bindMessageDiv.innerHTML = '';
        bindMessageDiv.className = '';

        if (!rolePassword) {
            showMessage('Введите код роли', 'error', bindMessageDiv);
            return;
        }

        try {
            const response = await fetch('/bind-role', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ login: currentLogin, role_password: rolePassword })
            });

            const result: BindRoleResponse = await response.json();

            if (response.ok && result.success) {
                localStorage.setItem('username', currentLogin);
                showMessage('Роль привязана! Перенаправление...', 'success', bindMessageDiv);
                setTimeout(() => window.location.href = '/user-info.html', 500);
            } else {
                const errorMsg = result.error || 'Ошибка привязки роли';
                showMessage(errorMsg, 'error', bindMessageDiv);
            }
        } catch (error) {
            console.error('Ошибка:', error);
            showMessage('Ошибка сети или сервера', 'error', bindMessageDiv);
        }
    });

    // Возврат на форму входа
    backToLogin.addEventListener('click', (e) => {
        e.preventDefault();
        bindContainer.style.display = 'none';
        loginContainer.style.display = 'block';
        // Очищаем поле ввода кода
        (document.getElementById('rolePassword') as HTMLInputElement).value = '';
        bindMessageDiv.innerHTML = '';
    });

    function showMessage(text: string, type: 'success' | 'error', element: HTMLElement) {
        element.textContent = text;
        element.classList.add(type);
    }
});