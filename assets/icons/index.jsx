import { View } from 'react-native'
import React from 'react'
import ImageIcon from './image'
import HomeIcon from './home'
import ArrowLeftIcon from './arrow_left'
import CallIcon from './call'
import LockPasswordIcon from './lock'
import MailIcon from './maill'
import UserIcon from './user'
import { theme } from '../../constants/theme'

const icons = {
    home: HomeIcon,
    image: ImageIcon,
    arrowLeft: ArrowLeftIcon,
    call: CallIcon,
    lock: LockPasswordIcon,
    mail: MailIcon,
    user: UserIcon,
}

const Icon = ({ name, ...props }) => {
    const IconComponent = icons[name]
    return (
        <View>
            <IconComponent
                heith={props.size || 24}
                width={props.size || 24}
                strokeWidth={props.strokeWidth || 1.9}
                color={theme.colors.textLight}
                {...props}
            />
        </View>
    )
}

export default Icon