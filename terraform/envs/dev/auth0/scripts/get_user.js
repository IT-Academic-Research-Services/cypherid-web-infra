function getByEmail(email, callback) {
    const Auth0 = require("auth0@2.17.0");

    const AUTH0_DOMAIN = configuration.AUTH0_DOMAIN;
    const AUTH0_CLIENT_ID = configuration.AUTH0_CLIENT_ID;
    const AUTH0_CLIENT_SECRET = configuration.AUTH0_CLIENT_SECRET;

    const CLIENT_CREDENTIAL_GRANT_OPTIONS = {
        audience: `https://${AUTH0_DOMAIN}/api/v2/`,
        grant_type: "client_credentials",
    };
    const AUTHENTICATION_CLIENT_OPTIONS = {
        domain: AUTH0_DOMAIN,
        clientId: AUTH0_CLIENT_ID,
        clientSecret: AUTH0_CLIENT_SECRET,
    };

    const _getAuthenticationClient = () =>
        new Auth0.AuthenticationClient(AUTHENTICATION_CLIENT_OPTIONS);
    const _getBearerToken = async () =>
        _getAuthenticationClient().clientCredentialsGrant(
            CLIENT_CREDENTIAL_GRANT_OPTIONS
        );
    let _managementClient = null;
    const _getManagementClient = async () => {
        _managementClient =
            _managementClient ||
            new Auth0.ManagementClient({
                token: (await _getBearerToken()).access_token,
                domain: AUTH0_DOMAIN,
            });
        return _managementClient;
    };

    async function getUserProfile(email) {
        const managementClient = await _getManagementClient();
        try {
            const u = await managementClient.getUser({
                id: `auth0|legacy_idseq|${email}`,
            });
            return {
                user_id: `auth0|idseq|${email}`,
                email: email,
                name: u.name,
                user_metadata: {},
                app_metadata: {
                    roles: u.app_metadata.roles,
                    legacy_password_hash: u.app_metadata.legacy_password_hash,
                    idseq_user_id: u.app_metadata.idseq_user_id,
                },
            };
        } catch (e) {
            if (e.statusCode === 404 && e.message.match(/user/)) {
                return null;
            }
            throw e;
        }
    }

    getUserProfile(email)
        .then(r => callback(null, r))
        .catch(callback);
}
