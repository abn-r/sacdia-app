import { StyleSheet, View, Text, Alert, Pressable } from 'react-native'
import React, { useRef, useState } from 'react'
import ScreenWrapper from '../components/screen_wrapper'
import Input from '../components/input'
import Button from '../components/button'
import { theme } from '../constants/theme'
import Icon from '../assets/icons'
import { StatusBar } from 'expo-status-bar'
import BackButton from '../components/BackButton'
import { useRouter } from 'expo-router'
import { hp, wp } from '../helpers/common'

const Login = () => {
    const router = useRouter();
    const emailRef = useRef('');
    const passwordRef = useRef('');
    const [loading, setLoading] = useState(false);

    const onSubmit = async () => {
        if (!emailRef.current || !passwordRef.current) {
            Alert.alert('Inicio de Sesión', 'Por favor ingresa tu correo y contraseña');
            return;
        }
    }
    return (
        <ScreenWrapper bg={'white'}>
            <StatusBar style='dark' />
            <View style={styles.container}>
                <BackButton router={router} />

                {/* welcome */}
                <View >
                    <Text style={styles.welcomeText}>Hey,</Text>
                    <Text style={styles.welcomeText}>Bienvenido</Text>
                </View>

                {/* form */}
                <View style={styles.form}>
                    <Text style={{ fontSize: hp(1.5), color: theme.colors.text }}>
                        Por favor inica sesión para continuar
                    </Text>
                    <Input
                        icon={<Icon name='mail' size={26} strokeWidth={1.6} />}
                        placeholder='Ingresa tu correo electrónico'
                        onChangeText={value => emailRef.current = value}
                    />
                    <Input
                        icon={<Icon name='lock' size={26} strokeWidth={1.6} />}
                        placeholder='Ingresa tu contraseña'
                        secureTextEntry
                        onChangeText={value => passwordRef.current = value}
                    />
                    <Text style={styles.forgotPassword}>
                        ¿Olvidaste tu contraseña?
                    </Text>
                    {/* Button */}
                    <Button title={'Iniciar Sesión'} loading={loading} onPress={onSubmit} />
                </View>

                {/* footer */}
                <View style={styles.footer}>
                    <Pressable onPress={() => router.push('signup')}>
                        <Text style={styles.footerText}>
                            ¿No tienes cuenta?
                        </Text>
                        <Text style={[
                            styles.footerText,
                            { color: theme.colors.primaryDark, fontWeight: theme.fonts.semibold }
                        ]}>
                            ¡Regístrate!
                        </Text>
                    </Pressable>
                </View>
            </View>
        </ScreenWrapper>
    )
}

export default Login

const styles = StyleSheet.create({
    container: {
        flex: 1,
        gap: 45,
        paddingHorizontal: wp(5),
    },
    welcomeText: {
        fontSize: hp(4),
        fontWeight: theme.fonts.bold,
        color: theme.colors.text,
    },
    form: {
        gap: 25
    },
    forgotPassword: {
        color: theme.colors.text,
        fontSize: hp(1.6),
        textAlign: 'right',
        fontWeight: theme.fonts.semibold,
    },
    footer: {
        flexDirection: 'row',
        justifyContent: 'center',
        alignItems: 'center',
        gap: 5,
    },
    footerText: {
        textAlign: 'center',
        color: theme.colors.text,
        fontSize: hp(1.6),
    },
})